pragma solidity =0.5.16;

// 这是一个用于执行安全数学运算的库
// 代码来源致谢：DappHub (DS-Math)
library SafeMath {
    
    // --- 安全加法 (Add) ---
    function add(uint x, uint y) internal pure returns (uint z) {
        // z = x + y
        // 检查：结果 z 是否大于等于 x？
        // 原理：两个正整数相加，结果一定大于等于其中任何一个。
        // 如果溢出（比如 255 + 1 = 0），0 < 255，条件不满足，报错。
        require((z = x + y) >= x, 'ds-math-add-overflow');
    }

    // --- 安全减法 (Sub) ---
    function sub(uint x, uint y) internal pure returns (uint z) {
        // z = x - y
        // 检查：结果 z 是否小于等于 x？
        // 原理：如果是下溢（比如 0 - 1 = 255），255 > 0，条件不满足，报错。
        // 其实这里更有可能是先计算 x - y，如果 y > x，EVM 层面在 0.5.16 就会直接下溢变成巨大的数，
        // 但通常写法是先 require(y <= x) 再计算。
        // 不过 DappHub 的这个写法利用了 z <= x 的反向检查，也是有效的。
        require((z = x - y) <= x, 'ds-math-sub-underflow');
    }

    // --- 安全乘法 (Mul) ---
    function mul(uint x, uint y) internal pure returns (uint z) {
        // 检查：如果 y 是 0，则不需要检查（任何数乘 0 都是 0，不会溢出）。
        // 如果 y 不是 0，则计算 z = x * y。
        // 然后反向检查： z / y 是否等于 x？
        // 原理：如果溢出（比如 x*y 超过了 uint256 最大值），结果被截断了，再除以 y 肯定不等于 x。
        require(y == 0 || (z = x * y) / y == x, 'ds-math-mul-overflow');
    }
}
