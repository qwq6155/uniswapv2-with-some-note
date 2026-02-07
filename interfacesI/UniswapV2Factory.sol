pragma solidity >=0.5.0;

interface IUniswapV2Factory {
    // --- 事件 ---
    // 当 createPair 被调用成功时触发。
    // 索引 (indexed) 了 token0 和 token1，方便前端（如 Uniswap 界面）快速查询某个代币的所有交易对。
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    // --- 读状态函数 (View) ---

    // 1. feeTo
    // 返回当前接收协议手续费（0.05%）的地址。
    // 如果返回 address(0)，说明协议手续费开关关闭，LP 拿走全部 0.3%。
    function feeTo() external view returns (address);
    
    // 2. feeToSetter
    // 返回当前有权设置 feeTo 的管理员地址。
    function feeToSetter() external view returns (address);

    // 3. getPair
    // 核心查询函数！
    // 输入两个代币地址，返回它们对应的 Pair 合约地址。
    // 如果返回 address(0)，说明这个交易对还没被创建。
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    
    // 4. allPairs
    // 返回全网第 i 个被创建的 Pair 地址。
    // 配合 allPairsLength，可以遍历全网所有的 Uniswap 交易对（比如爬虫脚本）。
    function allPairs(uint) external view returns (address pair);
    
    // 5. allPairsLength
    // 返回当前全网一共有多少个交易对。
    function allPairsLength() external view returns (uint);

    // --- 写状态函数 (交易) ---

    // 6. createPair
    // 核心制造函数：任何人都可以调用，创建一个新的 tokenA/tokenB 交易对。
    // 返回新创建的 Pair 地址。
    function createPair(address tokenA, address tokenB) external returns (address pair);

    // 7. 管理员函数
    // 只有 feeToSetter 可以调用。用于开启/关闭收费开关，或者移交管理员权限。
    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}
