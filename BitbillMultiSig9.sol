pragma solidity ^0.4.21;

// This is a ETH multisig contract for BITBILL.
//
// For 2-of-3 multisig, to authorize a spend, two signtures must be provided by 2 of the 3 owners.
// To generate the message to be signed, provide the destination address and
// spend amount (in wei) to the generateMessageToSignmethod.
// The signatures must be provided as the (v, r, s) hex-encoded coordinates.
// The S coordinate must be 0x00 or 0x01 corresponding to 0x1b and 0x1c, respectively.
// See the test file for example inputs.
//
// WARNING: The generated message is only valid until the next spend is executed.
//          after that, a new message will need to be calculated.
//
//
// ADDITIONAL WARNING: This contract is **NOT** ERC20 compatible.
// Tokens sent to this contract will be lost forever.
//
contract BitbillMultiSig9 {
    
    uint constant public MAX_OWNER_COUNT = 9;

  // The N addresses which control the funds in this contract.  The
  // owners of M of these addresses will need to both sign a message
  // allowing the funds in this contract to be spent.
  mapping(address => bool) private isOwner;
  address[] public owners;
  uint public required;

  // The contract nonce is not accessible to the contract so we
  // implement a nonce-like variable for replay protection.
  uint256 public spendNonce = 0;
  
  // An event sent when funds are received.
  event Funded(uint new_balance);
  
  // An event sent when a spend is triggered to the given address.
  event Spent(address to, uint transfer);
  
  modifier validRequirement(uint ownerCount, uint _required) {
        if (   ownerCount > MAX_OWNER_COUNT
            || _required > ownerCount
            || _required == 0
            || ownerCount == 0)
            throw;
        _;
    }
  
  /// @dev Contract constructor sets initial owners and required number of confirmations.
    /// @param _owners List of initial owners.
    /// @param _required Number of required confirmations.
    function BitbillMultiSig9(address[] _owners, uint _required)
        public
        validRequirement(_owners.length, _required)
    {
        for (uint i=0; i<_owners.length; i++) {
            if (isOwner[_owners[i]] || _owners[i] == 0)
                throw;
            isOwner[_owners[i]] = true;
        }
        owners = _owners;
        required = _required;
    }


  // The fallback function for this contract.
  function() public payable {
    Funded(this.balance);
  }
  
    /// @dev Returns list of owners.
    /// @return List of owner addresses.
    function getOwners()
        public
        constant
        returns (address[])
    {
        return owners;
    }

  // Generates the message to sign given the output destination address and amount.
  // includes this contract's address and a nonce for replay protection.
  // One option to  independently verify: https://leventozturk.com/engineering/sha3/ and select keccak
  function generateMessageToSign(address destination, uint256 value) public constant returns (bytes32) {
    require(destination != address(this));
    bytes32 message = keccak256(spendNonce, this, value, destination);
    return message;
  }
  
  function _messageToRecover(address destination, uint256 value) private constant returns (bytes32) {
    bytes32 hashedUnsignedMessage = generateMessageToSign(destination, value);
    bytes memory prefix = "\x19Ethereum Signed Message:\n32";
    return keccak256(prefix,hashedUnsignedMessage);
  }
  
  function spend(address destination, uint256 value, uint8[] vs, bytes32[] rs, bytes32[] ss) public {
    // This require is handled by generateMessageToSign()
    // require(destination != address(this));
    require(this.balance >= value);
    require(_validSignature(destination, value, vs, rs, ss));
    spendNonce = spendNonce + 1;
    destination.transfer(value);
    Spent(destination, value);
  }

  // Confirm that the signature triplets (v1, r1, s1) (v2, r2, s2) ...
  // authorize a spend of this contract's funds to the given
  // destination address.
  function _validSignature(address destination, uint256 value, uint8[] vs, bytes32[] rs, bytes32[] ss) private constant returns (bool) {
    require(vs.length == rs.length);
    require(rs.length == ss.length);
    require(vs.length <= owners.length);
    require(vs.length >= required);
    bytes32 message = _messageToRecover(destination, value);
    address[] memory addrs = new address[](vs.length);
    for (uint i=0; i<vs.length; i++) {
        //recover the address associated with the public key from elliptic curve signature or return zero on error 
        addrs[i]=ecrecover(message, vs[i]+27, rs[i], ss[i]);
    }
    require(_distinctOwners(addrs));
    return true;
  }
  
  // Confirm the addresses as distinct owners of this contract.
  function _distinctOwners(address[] addrs) private constant returns (bool) {
    if(addrs.length > owners.length)
        throw;
    for (uint i=0; i<addrs.length; i++) {
        //throw if 0 in case the signature is not right
        //or not the owner
        if (!isOwner[addrs[i]])
            throw;
    }
    for (uint j=0; j<addrs.length; j++) {
        for (uint k=0; k<addrs.length; k++) {
            if (addrs[j]==addrs[k] && j!=k)
                throw;
        }
    }
    
    return true;
  }
}
