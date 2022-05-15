// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract MyContract {

    uint8[3] taxes;
    address[3] public govAddresses;
    uint256[3] public gatheredVat;
    
    mapping(uint256 => uint256) private proceedPerId;

    struct VatLevels {
        uint8 high;
        uint8 mid;
        uint8 low;
    }

    struct MaxProceeds {
        uint256 id;
        address addr;
    }

    address public owner;
    VatLevels public vatLevels = VatLevels(24, 13, 6);
    MaxProceeds private s_maxProceeds;
    uint256 private maxProceeds;
    uint256 constant public MAX_NONVAT = 50000000000000000;

    constructor(address gov1, address gov2, address gov3) {
        owner = msg.sender;
        maxProceeds = 0;

        taxes = [vatLevels.high, vatLevels.mid, vatLevels.low];
        govAddresses = [gov1, gov2, gov3];
        gatheredVat = [0, 0, 0];
    }

    modifier onlyOwner {
      require(
         msg.sender == owner,
         "Unauthorized access"
      );
      _;
    }

    modifier costs(uint amount) {
      require(
         msg.value <= amount,
         "Exceeded max limit."
      );
      _;
    }

    event LogMsg1(address to, uint256 amount);
    event LogMsg2(address to, uint256 amount, uint8 vatLevel);
    event LogMsg3(address to, uint256 amount, uint8 vatLevel, string comment);


    function sendFunds(address destination) public payable costs(MAX_NONVAT) {
        require(checkBalance(msg.sender) > msg.value);

        payable(destination).transfer(msg.value);
        emit LogMsg1(destination, msg.value);
    }

    function sendFunds(address destination, uint taxId, uint8 idx) public payable {
        require(checkIndexValidity(idx));
        require(checkBalance(msg.sender) > msg.value);

        uint256 tax = msg.value * taxes[idx] / 100 ;

        payable(destination).transfer(msg.value - tax);
        payable(govAddresses[idx]).transfer(tax);

        proceedPerId[taxId] += msg.value - tax;
        gatheredVat[idx] += tax;

        if (proceedPerId[taxId] > maxProceeds) {
            s_maxProceeds.id = taxId;
            s_maxProceeds.addr = destination;
            maxProceeds = proceedPerId[taxId];
        }

        emit LogMsg2(destination, msg.value, idx);
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
        proceedPerId[taxId] += msg.value - tax;

        if (proceedPerId[taxId] > maxProceeds) {
            s_maxProceeds.id = taxId;
            s_maxProceeds.addr = destination;
            maxProceeds = proceedPerId[taxId];
        }

        emit LogMsg3(destination, msg.value, idx, comment);
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

    function getMaxProceedsPerson() public view onlyOwner returns(uint256, address) {
        return (s_maxProceeds.id, s_maxProceeds.addr);
    }
    
    function checkIndexValidity(uint8 index) public pure returns(bool) {
        return (index == 0 || index == 1 || index == 2);
    } 

    function checkBalance(address addr) public view returns(uint256) {
        return addr.balance;
    }
    
    function destroy() public onlyOwner {
        selfdestruct(payable(owner));
    }

    receive() external payable {}
}
