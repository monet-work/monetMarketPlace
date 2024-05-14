// SPDX-License-Identifier: MIT 

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Point is ERC20 
{
    address public owner; //owner of this exact point contract (a web3 company)
    address public MONET; //the address that we will use for signing 
    uint8 decimal; //decimals of this exact point

    mapping(address => uint256) public nonces;
    mapping(bytes32 => bool) public usedSignatures;

    event pointsMinted(address user,uint256 value);

    error usedSignature(address user, bytes signature);
    error wrongSignature(address user, bytes signature);

    constructor(
        address _owner,
        address _MONET,
        uint8 _decimal,
        string memory _pointName,
        string memory _pointSymbol
    ) ERC20(_pointName,_pointSymbol)
    {
        owner=_owner;
        MONET=_MONET;
        decimal=_decimal;
    }

    function decimals() public view override returns (uint8)
    {
        return decimal;
    }

    function mintYourPoints(uint256 points, bytes memory signature) external
   {
        //re-creating the message that MONET signed
        bytes32 messageHash = getMessageHash(msg.sender, points, nonces[msg.sender]);
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);

        //checks
        if (usedSignatures[ethSignedMessageHash])
        {
            revert usedSignature(msg.sender, signature);
        }
        if (recover(ethSignedMessageHash, signature)!=MONET)
        {
            revert wrongSignature(msg.sender,signature);
        }

        //actions
        nonces[msg.sender]++;
        usedSignatures[ethSignedMessageHash] = true;
        _mint(msg.sender,points);
        emit pointsMinted(msg.sender,points);
    }




    //Signature related funcitons
    function getMessageHash(address _user, uint256 _points, uint256 _nonce) public pure returns(bytes32)
    {
        return keccak256(abi.encodePacked(_user,_points,_nonce));
    }

    function getEthSignedMessageHash(bytes32 _messageHash) public pure returns(bytes32)
    {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32",_messageHash));
    }

    function recover(bytes32 _ethSignedMessageHash, bytes memory _sig) public pure returns (address)
    {
        (bytes32 r, bytes32 s, uint8 v) =_split(_sig);
        return ecrecover(_ethSignedMessageHash,v,r,s);
    }

    function _split(bytes memory _sig) internal pure returns(bytes32 r, bytes32 s, uint8 v)
    {
        require (_sig.length==65,"invalid signature length");

        assembly{
            r:= mload(add(_sig,32))
            s:= mload(add(_sig,64))
            v:= byte(0,mload(add(_sig,96)))
        }
    }

}
