pragma solidity >=0.5.0;

interface IUniswapV2ERC20 {
    // --- 标准 ERC20 事件 ---
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    // --- 标准 ERC20 元数据 ---
    // 注意：这里用了 pure，因为在实现合约里它们是常量 (constant)，不读取存储槽
    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    
    // --- 标准 ERC20 状态查询 ---
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    // --- 标准 ERC20 交互 ---
    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    // --- EIP-2612 (Permit) 核心扩展功能 ---
    // 这是 LP Token 最强大的地方：支持“无 Gas 授权”
    
    // 1. DOMAIN_SEPARATOR
    // 用于 EIP-712 签名。包含链 ID 和合约地址。
    // 作用：防止重放攻击。你在以太坊主网签名的授权，不能被黑客拿到 Polygon 链上去用。
    function DOMAIN_SEPARATOR() external view returns (bytes32);
    
    // 2. PERMIT_TYPEHASH
    // 签名的类型哈希。
    // 固定值：keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    
    // 3. nonces
    // 用户的交易计数器。
    // 作用：防止同一条签名被使用两次。每次 permit 成功，nonce 就会 +1。
    function nonces(address owner) external view returns (uint);

    // 4. permit
    // 核心函数：通过签名来设置 allowance。
    // owner: 授权人
    // spender: 被授权人
    // value: 授权金额
    // deadline: 签名有效期（过期作废）
    // v, r, s: 椭圆曲线数字签名 (ECDSA) 的三个部分
    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
}
