pragma solidity ^0.4.17;

contract Owned {
	modifier onlyOwner {
		require(msg.sender == owner);
		_;
	}

	event NewOwner(address indexed old, address indexed current);

	function setOwner(address _new) onlyOwner public {
		emit NewOwner(owner, _new);
		owner = _new;
	}

	address public owner = msg.sender;
}

contract MetadataRegistry {
	event DataChanged(bytes32 indexed name, string indexed key, string plainKey);

	function getData(bytes32 _name, string _key) view public returns (bytes32);
	function getAddress(bytes32 _name, string _key) view public returns (address);
	function getUint(bytes32 _name, string _key) view public returns (uint);
}

contract OwnerRegistry {
	event Reserved(bytes32 indexed name, address indexed owner);
	event Transferred(bytes32 indexed name, address indexed oldOwner, address indexed newOwner);
	event Dropped(bytes32 indexed name, address indexed owner);

	function getOwner(bytes32 _name) view public returns (address);
}

contract ReverseRegistry {
	event ReverseConfirmed(string indexed name, address indexed reverse);
	event ReverseRemoved(string indexed name, address indexed reverse);

	function hasReverse(bytes32 _name) view public returns (bool);
	function getReverse(bytes32 _name) view public returns (address);
	function canReverse(address _data) view public returns (bool);
	function reverse(address _data) view public returns (string);
}


contract SimpleRegistry is Owned, MetadataRegistry, OwnerRegistry, ReverseRegistry {
	struct Entry {
		address owner;
		address reverse;
		mapping (string => bytes32) data;
	}

	mapping (bytes32 => Entry) entries;
	mapping (address => string) reverses;

	uint public fee = 1 ether;
	
	event Drained(uint amount);
	event FeeChanged(uint amount);
	event ReverseProposed(string indexed name, address indexed reverse);

	modifier whenUnreserved(bytes32 _name) {
		if (entries[_name].owner != 0)
			return;
		_;
	}

	modifier onlyOwnerOf(bytes32 _name) {
		if (entries[_name].owner != msg.sender)
			return;
		_;
	}

	modifier whenProposed(string _name) {
		if (entries[keccak256(_name)].reverse != msg.sender)
			return;
		_;
	}

	modifier whenFeePaid {
		if (msg.value < fee)
			return;
		_;
	}

	// Registry functions.
	function getData(bytes32 _name, string _key) view public returns (bytes32) {
		return entries[_name].data[_key];
	}

	function getAddress(bytes32 _name, string _key) view public returns (address) {
		return address(entries[_name].data[_key]);
	}

	function getUint(bytes32 _name, string _key) view public returns (uint) {
		return uint(entries[_name].data[_key]);
	}

	// OwnerRegistry function.
	function getOwner(bytes32 _name) view public returns (address) {
		return entries[_name].owner;
	}

	// ReversibleRegistry functions.
	function hasReverse(bytes32 _name) view public returns (bool) {
		return entries[_name].reverse != 0;
	}

	function getReverse(bytes32 _name) view public returns (address) {
		return entries[_name].reverse;
	}

	function canReverse(address _data) view public returns (bool) {
		return bytes(reverses[_data]).length != 0;
	}

	function reverse(address _data) view public returns (string) {
		return reverses[_data];
	}

	// Reservation functions.
	function reserve(bytes32 _name) whenUnreserved(_name) whenFeePaid payable public returns (bool success) {
		entries[_name].owner = msg.sender;
		emit Reserved(_name, msg.sender);
		return true;
	}

	function reserved(bytes32 _name) view public returns (bool) {
		return entries[_name].owner != 0;
	}

	function transfer(bytes32 _name, address _to) onlyOwnerOf(_name) public returns (bool success) {
		entries[_name].owner = _to;
		emit Transferred(_name, msg.sender, _to);
		return true;
	}

	function drop(bytes32 _name) onlyOwnerOf(_name) public returns (bool success) {
		delete reverses[entries[_name].reverse];
		delete entries[_name];
		emit Dropped(_name, msg.sender);
		return true;
	}

	// Data admin functions.
	function setData(bytes32 _name, string _key, bytes32 _value) onlyOwnerOf(_name) public returns (bool success) {
		entries[_name].data[_key] = _value;
		emit DataChanged(_name, _key, _key);
		return true;
	}

	function setAddress(bytes32 _name, string _key, address _value) onlyOwnerOf(_name) public returns (bool success) {
		entries[_name].data[_key] = bytes32(_value);
		emit DataChanged(_name, _key, _key);
		return true;
	}

	function setUint(bytes32 _name, string _key, uint _value) onlyOwnerOf(_name) public returns (bool success) {
		entries[_name].data[_key] = bytes32(_value);
		emit DataChanged(_name, _key, _key);
		return true;
	}

	// Reverse registration.
	function proposeReverse(string _name, address _who) onlyOwnerOf(keccak256(_name)) public returns (bool success) {
		bytes32 sha3Name = keccak256(_name);
		if (entries[sha3Name].reverse != 0 && keccak256(reverses[entries[sha3Name].reverse]) == sha3Name) {
			delete reverses[entries[sha3Name].reverse];
			emit ReverseRemoved(_name, entries[sha3Name].reverse);
		}
		entries[sha3Name].reverse = _who;
		emit ReverseProposed(_name, _who);
		return true;
	}

	function confirmReverse(string _name) whenProposed(_name) public returns (bool success) {
		reverses[msg.sender] = _name;
		emit ReverseConfirmed(_name, msg.sender);
		return true;
	}

	function confirmReverseAs(string _name, address _who) onlyOwner public returns (bool success) {
		reverses[_who] = _name;
		emit ReverseConfirmed(_name, _who);
		return true;
	}

	function removeReverse() public {
		emit ReverseRemoved(reverses[msg.sender], msg.sender);
		delete entries[keccak256(reverses[msg.sender])].reverse;
		delete reverses[msg.sender];
	}

	// Admin functions for the owner.
	function setFee(uint _amount) onlyOwner public returns (bool) {
		fee = _amount;
		emit FeeChanged(_amount);
		return true;
	}

	function drain() onlyOwner public returns (bool) {
		emit Drained(address(this).balance);
		msg.sender.transfer(address(this).balance);
		return true;
	}
}
