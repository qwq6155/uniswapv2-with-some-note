pragma solidity =0.5.16; // Uniswap V2 选用的版本，现在看比较老，需要注意算术溢出问题

import './interfaces/IUniswapV2ERC20.sol';
import './libraries/SafeMath.sol';

contract UniswapV2ERC20 is IUniswapV2ERC20 {
    // 使用 SafeMath 防止 uint 溢出（Solidity 0.8.x 之前必须步骤）
    using SafeMath for uint;

    // --- 标准 ERC20 变量 ---
    string public constant name = 'Uniswap V2'; // 代币名称
    string public constant symbol = 'UNI-V2';   // 代币符号
    uint8 public constant decimals = 18;        // 精度
    uint  public totalSupply;                   // 总供应量（随流动性添加/移除而变动）
    
    // 记录余额映射：地址 -> 余额
    mapping(address => uint) public balanceOf;
    // 记录授权映射：持有者 ->  spender -> 授权额度
    mapping(address => mapping(address => uint)) public allowance;

    // --- EIP-712 / EIP-2612 (Permit) 变量 ---
    // DOMAIN_SEPARATOR 用于防止签名在不同 DApp 或不同链之间重放
    bytes32 public DOMAIN_SEPARATOR;
    
    // PERMIT_TYPEHASH 是 Permit 函数签名的哈希值，常量
    // 对应: keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    
    // nonces 用于防止同一个签名被多次使用（重放攻击）
    mapping(address => uint) public nonces;

    // --- 事件 ---
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    constructor() public {
        uint chainId;
        // 在 Solidity 0.5.16 中，无法直接通过 block.chainid 获取链 ID
        // 需要使用内联汇编调用 chainid 操作码 (opcode 0x46)
        assembly {
            chainId := chainid
        }
        // 计算 EIP-712 的 DOMAIN_SEPARATOR
        // 包含：协议名、版本号、链ID、合约地址
        // 这意味着如果你 fork 了代码部署到别的链，或者改了名字，签名就会失效，以此保证安全
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
                keccak256(bytes(name)),
                keccak256(bytes('1')),
                chainId,
                address(this)
            )
        );
    }

    // --- 内部函数：铸造代币 ---
    // 只有 UniswapV2Pair（子合约）会调用它，用于给添加流动性的人发 LP Token
    function _mint(address to, uint value) internal {
        totalSupply = totalSupply.add(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(address(0), to, value);
    }

    // --- 内部函数：销毁代币 ---
    // 用于移除流动性时，销毁 LP Token 以换回底层资产
    function _burn(address from, uint value) internal {
        balanceOf[from] = balanceOf[from].sub(value);
        totalSupply = totalSupply.sub(value);
        emit Transfer(from, address(0), value);
    }

    // --- 内部函数：授权逻辑 ---
    function _approve(address owner, address spender, uint value) private {
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    // --- 内部函数：转账逻辑 ---
    function _transfer(address from, address to, uint value) private {
        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(from, to, value);
    }

    // --- 外部函数：标准 approve ---
    function approve(address spender, uint value) external returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    // --- 外部函数：标准 transfer ---
    function transfer(address to, uint value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    // --- 外部函数：标准 transferFrom ---
    function transferFrom(address from, address to, uint value) external returns (bool) {
        // ! 重要优化：无限授权检查
        // 如果授权额度是 uint(-1) 即最大整数，则不扣减授权额度
        // 这就是为什么你在 DeFi 经常看到“无限授权”以节省 Gas
        if (allowance[from][msg.sender] != uint(-1)) {
            allowance[from][msg.sender] = allowance[from][msg.sender].sub(value);
        }
        _transfer(from, to, value);
        return true;
    }

    // --- 核心功能：Permit (EIP-2612) ---
    // 允许用户在链下签名，然后由其他人（如路由合约）提交签名来执行授权
    // 这样用户就不需要先发一笔 approve 交易（省钱、体验好）
    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external {
        // 1. 检查签名是否过期
        require(deadline >= block.timestamp, 'UniswapV2: EXPIRED');
        
        // 2. 构造 EIP-712 的摘要 (Digest)
        // 格式：0x1901 + DomainSeparator + Hash(Struct)
        bytes32 digest = keccak256(
            abi.encodePacked(
                '\x19\x01',
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline))
            )
        );
        
        // 3. 使用 ecrecover 恢复签名者地址
        address recoveredAddress = ecrecover(digest, v, r, s);
        
        // 4. 验证签名者是否为 owner，且地址有效
        require(recoveredAddress != address(0) && recoveredAddress == owner, 'UniswapV2: INVALID_SIGNATURE');
        
        // 5. 执行授权
        _approve(owner, spender, value);
    }
}
