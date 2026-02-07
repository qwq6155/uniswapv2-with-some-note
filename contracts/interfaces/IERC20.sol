pragma solidity >=0.5.0;

// interface 关键字：接口。
// 接口就像是一个“蓝图”或“合同”。它只定义了“应该有哪些函数”，但不包含具体的代码实现。
// 任何想被称为 "ERC20 Token" 的合约，都必须实现下面这些函数。
interface IERC20 {
    
    // --- 事件 (Events) ---
    // 链下应用（如 Etherscan、前端页面）通过监听这些事件来更新用户的余额显示。
    // indexed 关键字：表示这个参数会被编入索引，允许通过 owner 或 spender 进行快速搜索。
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    // --- 元数据函数 (Metadata) ---
    // external 关键字：表示这些函数只能从合约外部调用（省 Gas）。
    // view 关键字：表示这些函数只读取状态，不修改状态（不消耗 Gas，除非是在合约内部调用）。
    
    function name() external view returns (string memory);   // 代币名称，如 "Uniswap V2"
    function symbol() external view returns (string memory); // 代币符号，如 "UNI-V2"
    function decimals() external view returns (uint8);       // 精度，通常是 18
    
    // --- 读状态函数 ---
    
    // 返回代币的总供应量
    function totalSupply() external view returns (uint);
    
    // 返回某个地址 (owner) 的余额
    function balanceOf(address owner) external view returns (uint);
    
    // 返回 owner 授权给 spender 还能动用多少代币
    // 这是 DeFi 交互的核心查询函数
    function allowance(address owner, address spender) external view returns (uint);

    // --- 写状态函数 (交易) ---

    // 1. 授权 (Approve)
    // msg.sender (用户) 允许 spender (比如 Uniswap Router) 动用自己 value 数量的代币。
    // 这是一个“信任”操作。
    function approve(address spender, uint value) external returns (bool);

    // 2. 主动转账 (Push)
    // msg.sender 把自己的币转给 to。
    // 场景：你直接把币发给朋友。
    function transfer(address to, uint value) external returns (bool);

    // 3. 被动转账 / 划转 (Pull)
    // 这是一个高频考点！
    // msg.sender (通常是合约，如 Router) 把 from (用户) 的币转给 to (通常是 Pair 合约)。
    // 前提是：from 必须先调用过 approve 给 msg.sender。
    // 场景：你在 Uniswap 交易时，Router 实际上是调用这个函数把你的币“拉”进池子的。
    function transferFrom(address from, address to, uint value) external returns (bool);
}
