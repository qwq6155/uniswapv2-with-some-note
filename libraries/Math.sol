pragma solidity =0.5.16;

// 一个用于执行各种数学运算的库
// library 关键字：库函数。它们是无状态的，通常嵌入到调用它们的合约中（如果函数是 internal 的话）。
library Math {
    
    // --- 最小值函数 ---
    // 作用：返回 x 和 y 中较小的那个。
    // 这是一个纯逻辑判断，消耗 Gas 极少。
    function min(uint x, uint y) internal pure returns (uint z) {
        z = x < y ? x : y;
    }

    // --- 开平方根函数 (Square Root) ---
    // 这是一个面试高频考点！“如何在 Solidity 里写开根号？”
    // 使用的是：巴比伦法 (Babylonian Method)，也叫牛顿迭代法。
    // https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method
    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            // 初始猜测值 z = y
            z = y;
            // 第一次迭代：x = y / 2 + 1
            uint x = y / 2 + 1;
            
            // 开始循环迭代，直到 x 收敛（即 x 不再小于 z）
            // 每次迭代，x 都会越来越接近真实的平方根
            while (x < z) {
                z = x;
                // 迭代公式：x_new = (y / x_old + x_old) / 2
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            // 处理小数值：如果是 1, 2, 3，平方根取整都是 1
            z = 1;
        }
        // 如果 y == 0，z 默认为 0（返回值默认初始化为0），不需要显式赋值
    }
}
