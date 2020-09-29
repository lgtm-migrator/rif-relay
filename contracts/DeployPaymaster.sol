// SPDX-License-Identifier:MIT
pragma solidity ^0.6.2;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./forwarder/IForwarder.sol";
import "./BasePaymaster.sol";

/**
 * A paymaster to be used on deploys.
 * - We maintain the interface but not the functions, mainly to be
 * - GSN compatible
 */
contract DeployPaymaster is BasePaymaster {
    using SafeMath for uint256;

    function versionPaymaster() external override virtual view returns (string memory){
        return "2.0.0-beta.1+opengsn.token.ipaymaster";
    }

    IERC20[] public tokens;

    uint public gasUsedByPost;

    /**
     * set gas used by postRelayedCall, for proper gas calculation.
     * You can use TokenGasCalculator to calculate these values (they depend on actual code of postRelayedCall)
     */
    function setPostGasUsage(uint _gasUsedByPost) external onlyOwner {
        gasUsedByPost = _gasUsedByPost;
    }

    /**
     * Check if a contract has code in it
     * Should NOT be used on contructor, it fails
     * See: https://stackoverflow.com/a/54056854
     */
    function _isContract(address _addr) private returns (bool isContract){
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    function _checkAddressDoesNotExist(GsnTypes.RelayRequest calldata relayRequest) public virtual view {
        address owner = relayRequest.request.from;
        address logic = address(GsnUtils.getParam(relayRequest.request.data, 2));
        bytes memory initParams = GsnUtils.getParam(relayRequest.request.data, 3);

        address creationAddress = ProxyFactory.getAddress(owner, logic, initParams);
        // Create2 address are in a very specific address space
        // Not colliding with EOA
        // So we should check if the address is already a contract
        require(!_isContract(creationAddress), "Address already created!");
    }

    // return the payer of this request.
    // for account-based target, this is the target account.
    function getPayer(GsnTypes.RelayRequest calldata relayRequest) public virtual view returns (address) {
        (this);
        return relayRequest.request.from;
    }

    function getToken(GsnTypes.RelayRequest calldata relayRequest) public virtual view returns (IERC20) {
        (this);
        return IERC20(relayRequest.request.tokenContract);
    }

    function getTokenPrecharge(GsnTypes.RelayRequest calldata relayRequest) public virtual view returns (uint256) {
        (this);
        return relayRequest.request.paybackTokens;
    }

    event Received(uint eth);
    receive() external override payable {
        emit Received(msg.value);
    }

// fijarse que no exista si es un deploy
// realizar verificaciones en la llamada de un contracto
// getAddress de factory
// llamar a getAddress y obtener el address que va a tener el smartwallet
    function preRelayedCallInternal(
        GsnTypes.RelayRequest calldata relayRequest
    )
    public
    returns (bytes memory context, bool revertOnRecipientRevert) {
        address payer = this.getPayer(relayRequest);
        IERC20 token = this.getToken(relayRequest);
        uint256 tokenPrecharge = this.getTokenPrecharge(relayRequest);

        _verifyForwarder(relayRequest);
        require(tokenPrecharge <= token.balanceOf(payer), "balance too low");

        _checkAddressDoesNotExist(relayRequest);

        //We dont do that here
        //token.transferFrom(payer, address(this), tokenPrecharge);
        return (abi.encode(payer, tokenPrecharge, token), true);
    }

     function preRelayedCall(
        GsnTypes.RelayRequest calldata relayRequest,
        bytes calldata signature,
        bytes calldata approvalData,
        uint256 maxPossibleGas
    )
    external
    override
    virtual
    relayHubOnly
    returns (bytes memory context, bool revertOnRecipientRevert) {
        return preRelayedCallInternal(relayRequest);
    }

    function postRelayedCall(
        bytes calldata context,
        bool success,
        uint256 gasUseWithoutPost,
        GsnTypes.RelayData calldata relayData
    )
    external
    override
    virtual
    relayHubOnly {
        // for now we dont produce any refund
        // so there is nothing to be done here
    }

    event TokensCharged(uint gasUseWithoutPost, uint gasJustPost, uint ethActualCharge, uint tokenActualCharge);
}