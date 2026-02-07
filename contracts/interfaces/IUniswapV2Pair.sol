pragma solidity >=0.5.0;

interface IUniswapV2Pair {
    // ==========================================
    //Part 1: ERC20 & Permit 部分 (LP Token 属性)
    // ==========================================
    
    // 标准 ERC20 事件
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    // 标准 ERC20 查询函数
    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    // 标准 ERC20 操作函数
    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    // EIP-2612 Permit 签名授权函数
    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);
    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    // ==========================================
    // Part 2: AMM 核心业务部分 (交易池属性)
    // ==========================================

    // --- 核心事件 ---
    // Mint: 添加流动性时触发
    event Mint(address indexed sender, uint amount0, uint amount1);
    // Burn: 移除流动性时触发
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    // Swap: 发生交易时触发 (核心中的核心)
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    // Sync: 当储备金更新时触发 (用于轻节点或数据看板同步数据)
    event Sync(uint112 reserve0, uint112 reserve1);

    // --- 状态查询函数 (View) ---

    // 最小流动性锁定数量 (1000 wei)
    function MINIMUM_LIQUIDITY() external pure returns (uint);
    
    // 返回工厂合约地址
    function factory() external view returns (address);
    
    // 返回交易对中的两个代币地址
    function token0() external view returns (address);
    function token1() external view returns (address);
    
    // 获取当前储备量
    // blockTimestampLast 用于预言机计算时间加权平均价格 (TWAP)
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    
    // 获取累计价格 (预言机数据源)
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    
    // 获取上一次交易后的 K 值 (用于计算协议手续费)
    function kLast() external view returns (uint);

    // --- 核心操作函数 (Low-Level) ---
    // 注意：这些通常不由用户直接调用，而是由 Router 合约调用
    
    // 铸造 LP Token (添加流动性底层函数)
    function mint(address to) external returns (uint liquidity);
    
    // 销毁 LP Token (移除流动性底层函数)
    function burn(address to) external returns (uint amount0, uint amount1);
    
    // 交易函数 (Swap底层函数)
    // data 参数不为空时，触发闪电贷
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    
    // 强制平衡 (救火函数)
    // 比如有人误转了 token 进来，reserve 和 balance 对不上了，调用 skim 把多余的钱转给 to
    function skim(address to) external;
    
    // 强制同步
    // 更新 reserve = balance，通常用于处理包含重设基准 (Rebase) 机制的代币
    function sync() external;

    // --- 初始化函数 ---
    // 工厂合约创建 Pair 后立刻调用，设置 token0 和 token1
    function initialize(address, address) external;
}
