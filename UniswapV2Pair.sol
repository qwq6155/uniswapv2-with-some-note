pragma solidity =0.5.16;

import './interfaces/IUniswapV2Pair.sol';
import './UniswapV2ERC20.sol';
import './libraries/Math.sol';
import './libraries/UQ112x112.sol';
import './interfaces/IERC20.sol';
import './interfaces/IUniswapV2Factory.sol';
import './interfaces/IUniswapV2Callee.sol';

contract UniswapV2Pair is IUniswapV2Pair, UniswapV2ERC20 {
    using SafeMath  for uint;
    // UQ112x112 是一个定点数库，用于处理价格累积（预言机功能）
    using UQ112x112 for uint224;

    // 最小流动性：1000 wei。
    // 这部分 LP Token 会被永久锁定在 address(0)，用于防止攻击者将 total supply 操纵得极小从而抬高每个 share 的价格
    uint public constant MINIMUM_LIQUIDITY = 10**3;
    
    // ERC20 transfer 函数的选择器
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

    address public factory;
    address public token0;
    address public token1;

    // 使用 uint112 是为了打包存储 (Slot Packing)
    // reserve0 (14 bytes) + reserve1 (14 bytes) + blockTimestampLast (4 bytes) = 32 bytes
    // 正好塞满一个 Storage Slot，节省大量的 Gas（读一次 Slot 就拿全了）
    uint112 private reserve0;           
    uint112 private reserve1;           
    uint32  private blockTimestampLast; 

    // --- 价格预言机变量 ---
    // 累积价格：每一秒钟的价格都会累加到这个变量里
    // 外部合约可以通过读取两个时间点的 cumulativePrice 差值，除以时间差，算出这段时间的“时间加权平均价格 (TWAP)”
    uint public price0CumulativeLast;
    uint public price1CumulativeLast;
    
    // k 值记录：用于检查 k 值是否增长（判断是否有手续费产生）
    uint public kLast; 

    // --- 防重入锁 ---
    // 简单的 mutex 互斥锁。unlocked = 1 表示解锁，0 表示锁定。
    uint private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, 'UniswapV2: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    // 安全转账函数：处理那些返回值不规范的 Token（比如 USDT 有时候不返回 bool）
    function _safeTransfer(address token, address to, uint value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'UniswapV2: TRANSFER_FAILED');
    }

    // --- 事件定义 ---
    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    constructor() public {
        factory = msg.sender;
    }

    // 初始化：只能被 Factory 调用一次
    function initialize(address _token0, address _token1) external {
        require(msg.sender == factory, 'UniswapV2: FORBIDDEN'); 
        token0 = _token0;
        token1 = _token1;
    }

    // --- 核心更新函数 ---
    // 每次 Mint, Burn, Swap 后都会调用。更新 reserve 和预言机价格。
    function _update(uint balance0, uint balance1, uint112 _reserve0, uint112 _reserve1) private {
        // 防止溢出 uint112
        require(balance0 <= uint112(-1) && balance1 <= uint112(-1), 'UniswapV2: OVERFLOW');
        
        // 这里的 blockTimestamp 只取低 32 位，会循环溢出，但减法计算 timeElapsed 时会自动处理溢出，所以是安全的
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; 
        
        // 只有当这是区块内的第一笔交易时（timeElapsed > 0），才更新价格累积器
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            // 计算当前价格并乘以时间间隔，累加到 cumulativeLast
            // 价格 = reserve1 / reserve0 (UQ112x112 定点数格式)
            price0CumulativeLast += uint(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
            price1CumulativeLast += uint(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
        }
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve0, reserve1);
    }

    // --- 协议手续费逻辑 (Mint Fee) ---
    // 这是一个高难度的数学推导，目的是把 k 值增长的 1/6 铸造成 LP Token 给 feeTo 地址
    // 具体公式推导可以查阅 Uniswap 白皮书，面试通常只需要知道“有这个机制”即可
    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        address feeTo = IUniswapV2Factory(factory).feeTo();
        feeOn = feeTo != address(0);
        uint _kLast = kLast; 
        if (feeOn) {
            if (_kLast != 0) {
                uint rootK = Math.sqrt(uint(_reserve0).mul(_reserve1));
                uint rootKLast = Math.sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint numerator = totalSupply.mul(rootK.sub(rootKLast));
                    uint denominator = rootK.mul(5).add(rootKLast);
                    uint liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }

    // --- 铸造流动性 (Add Liquidity) ---
    // 外部（Router）先 transfer token0 和 token1 进来，然后调用 mint
    function mint(address to) external lock returns (uint liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); 
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));
        // 计算用户转进来了多少钱
        uint amount0 = balance0.sub(_reserve0);
        uint amount1 = balance1.sub(_reserve1);

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply; 
        
        // 首次添加流动性
        if (_totalSupply == 0) {
            // 几何平均数 sqrt(x*y) 作为初始流动性
            liquidity = Math.sqrt(amount0.mul(amount1)).sub(MINIMUM_LIQUIDITY);
            // 永久锁定最小流动性（防止攻击）
           _mint(address(0), MINIMUM_LIQUIDITY); 
        } else {
            // 后续添加：按当前储备比例计算，取最小值
            liquidity = Math.min(amount0.mul(_totalSupply) / _reserve0, amount1.mul(_totalSupply) / _reserve1);
        }
        require(liquidity > 0, 'UniswapV2: INSUFFICIENT_LIQUIDITY_MINTED');
        _mint(to, liquidity);

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint(reserve0).mul(reserve1); 
        emit Mint(msg.sender, amount0, amount1);
    }

    // --- 销毁流动性 (Remove Liquidity) ---
    // 用户先把 LP Token 转给 Pair 合约，然后调用 burn
    function burn(address to) external lock returns (uint amount0, uint amount1) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); 
        address _token0 = token0;                                
        address _token1 = token1;                                
        uint balance0 = IERC20(_token0).balanceOf(address(this));
        uint balance1 = IERC20(_token1).balanceOf(address(this));
        // 看用户转进来了多少 LP Token
        uint liquidity = balanceOf[address(this)];

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply; 
        
        // 按比例计算能取回多少 token0 和 token1
        // amount = (lp_burned / total_supply) * balance
        amount0 = liquidity.mul(balance0) / _totalSupply; 
        amount1 = liquidity.mul(balance1) / _totalSupply; 
        require(amount0 > 0 && amount1 > 0, 'UniswapV2: INSUFFICIENT_LIQUIDITY_BURNED');
        
        _burn(address(this), liquidity);
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint(reserve0).mul(reserve1); 
        emit Burn(msg.sender, amount0, amount1, to);
    }

    // --- 核心交易函数 (Swap) ---
    // 支持闪电贷 (Flash Swap)
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external lock {
        require(amount0Out > 0 || amount1Out > 0, 'UniswapV2: INSUFFICIENT_OUTPUT_AMOUNT');
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); 
        require(amount0Out < _reserve0 && amount1Out < _reserve1, 'UniswapV2: INSUFFICIENT_LIQUIDITY');

        uint balance0;
        uint balance1;
        { 
        address _token0 = token0;
        address _token1 = token1;
        require(to != _token0 && to != _token1, 'UniswapV2: INVALID_TO');
        
        // 1. 乐观转账 (Optimistic Transfer)
        // 先把钱给用户！这就是闪电贷的原理。用户还没给钱，合约先把币转出去了。
        if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out); 
        if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out); 
        
        // 2. 闪电贷回调 (Flash Swap Callback)
        // 如果 data 不为空，说明这是一笔闪电贷，调用接收者的回调函数
        if (data.length > 0) IUniswapV2Callee(to).uniswapV2Call(msg.sender, amount0Out, amount1Out, data);
        
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));
        }
        
        // 3. 计算用户实际输入了多少钱
        // input = current_balance - (reserve - output)
        uint amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, 'UniswapV2: INSUFFICIENT_INPUT_AMOUNT');
        
        // 4. K 值检查 (Constant Product Formula Check)
        // 扣除 0.3% 手续费后的 K 值必须大于等于原来的 K 值
        // balance * 1000 - amountIn * 3  =>  balance * (1 - 0.003)
        // 核心公式： (x_new * 997) * (y_new * 997) >= x_old * y_old
        { 
        uint balance0Adjusted = balance0.mul(1000).sub(amount0In.mul(3));
        uint balance1Adjusted = balance1.mul(1000).sub(amount1In.mul(3));
        require(balance0Adjusted.mul(balance1Adjusted) >= uint(_reserve0).mul(_reserve1).mul(1000**2), 'UniswapV2: K');
        }

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    // --- 强制平衡函数 ---
    // 如果有人误转了 token 进来，或者 token 余额变动了（如 rebasing token），可以调用 skim 把它取走或强制同步
    function skim(address to) external lock {
        address _token0 = token0; 
        address _token1 = token1; 
        _safeTransfer(_token0, to, IERC20(_token0).balanceOf(address(this)).sub(reserve0));
        _safeTransfer(_token1, to, IERC20(_token1).balanceOf(address(this)).sub(reserve1));
    }

    function sync() external lock {
        _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)), reserve0, reserve1);
    }
}
