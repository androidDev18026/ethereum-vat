
pragma solidity ^0.8.13;

contract MyContract {

    mapping(uint8 => uint8) public taxes;
    mapping(uint8 => address) public govAddresses;
    mapping(uint8 => uint256) public gatheredVat;
    mapping(uint256 => uint256) public largestProceedID;

    address public owner;
    address public maxProceedsAddress;
    uint256 public maxProceedsID;
    uint256 public maxProceeds;

    constructor(address gov1, address gov2, address gov3) {
        owner = msg.sender;
        maxProceeds = 0;
        taxes[0] = 24;
        govAddresses[0] = gov1;
        taxes[1] = 13;
        govAddresses[1] = gov2;
        taxes[2] = 6;
        govAddresses[2] = gov3;
        gatheredVat[0] = 0;
        gatheredVat[1] = 0;
        gatheredVat[2] = 0;
    }

    modifier onlyBy(address _account) {
      require(
         msg.sender == _account,
         "Sender not authorized."
      );
      _;
    }

    event SendSimpleTx(address from, address to, uint256 amount);
    event SendTx2(address from, address to, address gov, uint256 amount, uint256 tax);
    event SendTx3(address from, address to, address gov, uint256 amount, 
    uint256 tax, string comment, uint comm_size);


    function sendFunds(address destination) public payable {
        require(msg.value <= 50000000000000000);
        require(checkBalance(msg.sender) > msg.value);

        payable(destination).transfer(msg.value);
        emit SendSimpleTx(msg.sender, destination, msg.value);
    }

    function sendFunds(address destination, uint taxId, uint8 idx) public payable {
        require(checkIndexValidity(idx));
        require(checkBalance(msg.sender) > msg.value);

        uint256 tax = msg.value * taxes[idx] / 100 ;

        payable(destination).transfer(msg.value - tax);
        payable(govAddresses[idx]).transfer(tax);

        largestProceedID[taxId] += msg.value - tax;
        gatheredVat[idx] += tax;

        if (largestProceedID[taxId] > maxProceeds) {
            maxProceedsID = taxId;
            maxProceedsAddress = destination;
            maxProceeds = largestProceedID[taxId];
        }

        emit SendTx2(msg.sender, destination, govAddresses[idx], msg.value, tax);
    }

    function sendFunds(address destination, uint taxId, uint8 idx, 
    string memory comment) public payable {
        require(checkIndexValidity(idx));
        require(checkBalance(msg.sender) > msg.value);
        require(utfStringLength(comment) <= 80);

        uint256 tax = msg.value * taxes[idx] / 100 ;

        payable(destination).transfer(msg.value - tax);
        payable(govAddresses[idx]).transfer(tax);
        
        gatheredVat[idx] += tax;
        largestProceedID[taxId] += msg.value - tax;

        if (largestProceedID[taxId] > maxProceeds) {
            maxProceedsID = taxId;
            maxProceedsAddress = destination;
            maxProceeds = largestProceedID[taxId];
        }

        emit SendTx3(msg.sender, destination, govAddresses[idx], msg.value, tax, comment, utfStringLength(comment));
    }

    function utfStringLength(string memory str) pure internal returns (uint length) {
        uint i=0;
        bytes memory string_rep = bytes(str);

        while (i<string_rep.length)
        {
            if (string_rep[i]>>7==0)
                i+=1;
            else if (string_rep[i]>>5==bytes1(uint8(0x6)))
                i+=2;
            else if (string_rep[i]>>4==bytes1(uint8(0xE)))
                i+=3;
            else if (string_rep[i]>>3==bytes1(uint8(0x1E)))
                i+=4;
            else
                i+=1;

            length++;
        }
    }

    function getVatForLevel(uint8 level) public view returns(uint256) {
        require(checkIndexValidity(level));
        return gatheredVat[level];
    }

    function totalVat() public view returns(uint256) {
        return (gatheredVat[0] + gatheredVat[1] + gatheredVat[2]);
    }

    function getMaxProceedsPerson() public onlyBy(owner) returns(uint256, address) {
        return (maxProceedsID, maxProceedsAddress);
    }
    
    function checkIndexValidity(uint8 index) public pure returns(bool) {
        return (index == 0 || index == 1 || index == 2);
    } 

    function checkBalance(address addr) public view returns(uint256) {
        return addr.balance;
    }
    
    function destroy() public onlyBy(owner) {
        selfdestruct(payable(owner));
    }

    receive() external payable {}
}
