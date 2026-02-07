pragma solidity =0.5.16;

// 导入核心库里的 UniswapV2ERC20
// 这意味着这个 Mock Token 实际上拥有和 LP Token 一模一样的功能（包括 Permit）
import '../UniswapV2ERC20.sol';

// 定义一个名为 ERC20 的合约，继承自 UniswapV2ERC20
contract ERC20 is UniswapV2ERC20 {
    
    // 构造函数：在部署时执行一次
    // 参数 _totalSupply: 你想要发行多少代币
    constructor(uint _totalSupply) public {
        // 调用父合约 UniswapV2ERC20 的内部函数 _mint
        // 作用：给部署者 (msg.sender) 铸造指定数量 (_totalSupply) 的代币
        _mint(msg.sender, _totalSupply);
    }
}
