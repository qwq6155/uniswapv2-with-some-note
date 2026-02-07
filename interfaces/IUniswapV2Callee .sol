pragma solidity >=0.5.0;

// 接口名：IUniswapV2Callee
// Callee 意为“被调用者”。
// 在闪电贷场景中，Uniswap Pair 是调用者 (Caller)，你的合约是被调用者 (Callee)。
interface IUniswapV2Callee {
    
    // 函数名：uniswapV2Call
    // 当你在调用 Pair 的 swap 函数时，如果传入的 `data` 参数不为空，
    // Pair 合约就会认为你要发起闪电贷，并在转币给你之后，立刻回调你合约里的这个函数。
    function uniswapV2Call(
        address sender, // 发起 swap 交易的人（通常就是你的合约地址，或者是 Router）
        uint amount0,   // 你借到了多少 token0
        uint amount1,   // 你借到了多少 token1
        bytes calldata data // 你在 swap 函数里传入的自定义数据（比如告诉你的合约要去哪里套利）
    ) external;
}
