// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAccount} from "lib/account-abstraction/contracts/interfaces/IAccount.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {MessageHashUtils} from "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {SIG_VALIDATION_FAILED,SIG_VALIDATION_SUCCESS} from "lib/account-abstraction/contracts/core/Helpers.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";



contract MinimalAccount is IAccount , Ownable {

    IEntryPoint private immutable  i_entryPoint;

       modifier onlyEntryPoint() {
        require(msg.sender == address(i_entryPoint), "only EntryPoint can call this function");
        _;
    }

    modifier requireownerorEntryPoint() {
        require(msg.sender == owner() || msg.sender == address(i_entryPoint), "only EntryPoint or owner can call this function");
        _;
    }

    constructor( address entrypoint ) Ownable(msg.sender){
        i_entryPoint = IEntryPoint(entrypoint);
    }

     function validateUserOp( PackedUserOperation calldata userOp, bytes32 userOpHash,uint256 missingAccountFunds) external onlyEntryPoint returns (uint256 validationData)
     {
        
       validationData =  _validateSignature(userOp,userOpHash);
       _payPrefund(missingAccountFunds);
    }

//ophash is in EIP191 format of signature -> convert it to normal hash 
    function _validateSignature( PackedUserOperation calldata userOp, bytes32 userOpHash) internal view returns (uint256 validationData) {
     bytes32 ethSignedHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
     address signer = ECDSA.recover(ethSignedHash, userOp.signature);
     if (signer != owner()) {
         return SIG_VALIDATION_FAILED;
     }
     return SIG_VALIDATION_SUCCESS;

        
    }

    function _payPrefund(uint256 missingAccountFunds) internal {
        if (missingAccountFunds > 0) {
            // Transfer the missing funds to the account
            (bool success, ) = payable(msg.sender).call{value: missingAccountFunds,gas: type(uint256).max}("");
            require(success, "Failed to transfer funds");
        }
    }


    function getEntrypoint() external view returns (address) {
        return address(i_entryPoint);
    }

    function execute(address dest, uint256 value , bytes calldata func) external requireownerorEntryPoint returns (bool success) {
        (bool success,bytes memory result ) = dest.call{value: value}(func);
        if(!success) {
            revert();
        }
    }

    function recieve() external payable {
        // This function is empty, but it allows the contract to receive Ether.
    }

}