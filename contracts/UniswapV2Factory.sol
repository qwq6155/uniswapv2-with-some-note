pragma solidity =0.5.16;

import './interfaces/IUniswapV2Factory.sol';
import './UniswapV2Pair.sol';

contract UniswapV2Factory is IUniswapV2Factory {
    // 协议手续费接收地址
    // 如果这个地址不为 0，说明协议开启了收费开关（抽取 LP 收益的 1/6，即交易额的 0.05%）
    address public feeTo;
    
    // 有权设置 feeTo 地址的管理员（通常是 DAO 或多签钱包）
    address public feeToSetter;

    // 核心映射：tokenA -> tokenB -> Pair地址
    // 比如：getPair[USDT][ETH] = 0x...
    // 这是一个双向映射，A=>B 和 B=>A 都能查到同一个地址
    mapping(address => mapping(address => address)) public getPair;
    
    // 存储所有已创建 Pair 地址的数组，方便前端遍历展示所有交易对
    address[] public allPairs;

    // 事件：当代币对被创建时触发
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    constructor(address _feeToSetter) public {
        feeToSetter = _feeToSetter;
    }

    // 返回当前一共有多少个交易对
    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    // --- 核心函数：创建交易对 ---
    // 这是一个面试中非常高频的考点，尤其是关于 create2 和排序
    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, 'UniswapV2: IDENTICAL_ADDRESSES');
        
        // 1. 排序 (Sorting)
        // 强制要求 token0 地址小于 token1。
        // 为什么要排序？为了确定性。
        // 无论用户是 createPair(A, B) 还是 createPair(B, A)，
        // 生成的 token0 和 token1 永远是一样的顺序，确保 salt 一致，生成的地址也一致。
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        
        require(token0 != address(0), 'UniswapV2: ZERO_ADDRESS');
        
        // 2. 检查是否存在
        // 必须保证这个交易对之前没有被创建过
        require(getPair[token0][token1] == address(0), 'UniswapV2: PAIR_EXISTS'); 
        
        // 3. 获取 Pair 合约的创建字节码 (Creation Code)
        bytes memory bytecode = type(UniswapV2Pair).creationCode;
        
        // 4. 计算 Salt (加盐)
        // salt 是基于两个 token 地址生成的。
        // 因为 token0 和 token1 已经排序过，所以 salt 是唯一的、确定性的。
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        
        // 5. 使用 create2 部署合约 (内联汇编)
        // create2(value, offset, length, salt)
        // 它的神奇之处在于：只要 bytecode 和 salt 确定，部署出的合约地址就是确定的。
        // 这允许 Router 合约在不知道 Pair 地址的情况下，通过公式直接算出来 Pair 地址（节省一次链上查询请求，极其省 Gas）。
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        
        // 6. 初始化 Pair
        // 调用新部署合约的 initialize 函数，把 token0 和 token1 告诉它
        // 为什么不在构造函数里传？因为 create2 的计算公式依赖 bytecode，
        // 如果构造函数参数不同，bytecode 就不同，地址就无法预测了。所以必须先部署，再初始化。
        IUniswapV2Pair(pair).initialize(token0, token1);
        
        // 7. 记录注册表
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // 反向也存一份，方便查询
        allPairs.push(pair);
        
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    // --- 管理员功能：设置手续费接收者 ---
    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        feeTo = _feeTo;
    }

    // --- 管理员功能：移交管理员权限 ---
    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }
}
