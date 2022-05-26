// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/*
Author: Panagiotis Doupidis
A.M.: 89
Date: 15/05/22

-- Aristotle University of Thessaloniki
-- Data & Web Science MSc Program
-- Decentralized Technologies Course
=========================================
-- Assignment 2, 2022 - Ethereum
*/

contract GovDapp {
    // Array to store the 3 different VAT levels
    uint8[3] internal taxes;
    // List of goverment controlled addresses for each level
    address[] private govAddresses;
    // Array to store accumulated VAT for each level
    uint256[3] internal gatheredVat;

    /* 
    Store proceeds for each person/address that receives
    funds as an associative array mapping TaxID's to
    Wei's
    */
    mapping(uint256 => uint256) private proceedPerId;
    mapping(address => uint256) internal addressToId;

    struct VatLevels {
        uint8 high;
        uint8 mid;
        uint8 low;
    }

    // To store the person/address with the most proceeds
    struct MaxProceeds {
        uint256 id;
        address addr;
    }

    // The owner that deploys the contract
    address public owner;
    VatLevels public vatLevels = VatLevels(24, 13, 6);

    /* 
    Declare struct to store information about the
    recipient with the most proceeds, make sure it's
    private so that a getter method is not exposed
    */
    MaxProceeds private s_maxProceeds;
    uint256 private maxProceeds;

    // Max amount that VAT doesn't apply to (0.05 ETH -> Wei)
    uint256 public constant MAX_NONVAT = 50000000000000000;
    uint16 public constant MAX_SENTENCE_LENGTH = 80;

    // Define constructor that accepts list of gov. addresses
    constructor(address[] memory addresses) {
        // Make sure the deployed contract has 3 goverment addresses
        require(addresses.length >= 3, "Goverment addresses must be at least 3");
        // Owner of the contract is the one deploying it
        owner = msg.sender;
        // Initialize proceeds
        maxProceeds = 0;
        // Initialize each of the 3 arrays defined with values
        taxes = [vatLevels.high, vatLevels.mid, vatLevels.low];
        /* 
        The array to store the gov. controlled addresses is dynamic 
        so that in can potentially be used to store more than 3
        addresses in the future
        */
        govAddresses = new address[](3);
        
        govAddresses.push(addresses[0]);
        govAddresses.push(addresses[1]);
        govAddresses.push(addresses[2]);

        gatheredVat = [0, 0, 0];
    }

    /*
    Function modifier to restrict access only to the owner
    of the contract
    */
    modifier onlyOwner() {
        require(msg.sender == owner, "Unauthorized access");
        _;
    }

    /*
    Function modifier that constraints the amount of a transaction
    to a specific value (upper bound)
    */
    modifier costs(uint256 amount) {
        require(msg.value <= amount, "Exceeded max limit.");
        _;
    }

    // Initialize logging events for each overloaded function
    event LogMsg1(address to, uint256 amount);
    event LogMsg2(address to, uint256 amount, uint8 vatLevel);
    event LogMsg3(address to, uint256 amount, uint8 vatLevel, string comment);

    /*
    Transfers funds from one address to another only if the amount specified
    is <= 0.05 ETH enforced by the <costs> modifier declared above
    */
    function sendFunds(address destination) public payable costs(MAX_NONVAT) {
        // Transfer the funds without taking VAT into account
        payable(destination).transfer(msg.value);
        emit LogMsg1(destination, msg.value);
    }

    /* 
    Transfer funds from one address to another given that all prerequisites
    are met, meaning that the sender has the needed funds and a valid VAT level
    is passed as argument
    params: destination -> address to send funds to
            taxID -> the tax identification number of the recipient
            idx -> VAT level for that transaction (0,1,2)
    */
    function sendFunds(
        address destination,
        uint256 taxId,
        uint8 idx
    ) public payable {
        // Check if the VAT index is valid
        require(checkIndexValidity(idx), "Invalid index, [0, 1, 2] available");

        // Check for tax id validity
        if (!seenId(destination, taxId)) {
            addressToId[destination] = taxId;
        }

        // Calculate the VAT based on the index argument
        uint256 tax = (msg.value * taxes[idx]) / 100;

        // First, transfer part of the funds to destination address
        payable(destination).transfer(msg.value - tax);
        /* 
        Then, make a tax payment to the goverment controlled address
        for that level
        */
        payable(govAddresses[idx]).transfer(tax);

        // Update the proceeds of recipient with the current amount - tax
        proceedPerId[taxId] += msg.value - tax;
        // Update the total VAT for that level
        gatheredVat[idx] += tax;

        /*
        Check if the user with the most proceeds has changed
        after this transaction and update the struct accordingly.
        */
        if (proceedPerId[taxId] > maxProceeds) {
            s_maxProceeds.id = taxId;
            s_maxProceeds.addr = destination;
            maxProceeds = proceedPerId[taxId];
        }

        // Emit event if transaction is successful
        emit LogMsg2(destination, msg.value, idx);
    }

    /* Same as function above with the added functionality of adding comment
    params: destination -> address to send funds to
            taxID -> the tax identification number of the recipient
            idx -> VAT level for that transaction (0,1,2)
            comment -> comment to send along with the tx (< 80 characters)
    */
    function sendFunds(
        address destination,
        uint256 taxId,
        uint8 idx,
        string memory comment
    ) public payable {
        // Check if the VAT index is valid
        require(checkIndexValidity(idx), "Invalid index, [0, 1, 2] available");
        // Make sure the comment is not over the character limit
        require(
            utfStringLength(comment) <= MAX_SENTENCE_LENGTH,
            "Comment >80 characters"
        );

        // Check for tax id validity
        if (!seenId(destination, taxId)) {
            addressToId[destination] = taxId;
        }
        
        // Calculate the tax
        uint256 tax = (msg.value * taxes[idx]) / 100;

        // Pay the recipient after subtracting taxes
        payable(destination).transfer(msg.value - tax);
        // Pay the goverment the amount of tax corresponding to that level
        payable(govAddresses[idx]).transfer(tax);

        // Add current tax to the total amassed for that level 
        gatheredVat[idx] += tax;
        // Update the proceedings of the recipient
        proceedPerId[taxId] += msg.value - tax;

        // Check to see if the recipient with the most proceeding changed
        if (proceedPerId[taxId] > maxProceeds) {
            s_maxProceeds.id = taxId;
            s_maxProceeds.addr = destination;
            maxProceeds = proceedPerId[taxId];
        }

        emit LogMsg3(destination, msg.value, idx, comment);
    }

    function seenId(address addr, uint256 id) internal view returns (bool) {
        if (addressToId[addr] != 0x0) {
            if (addressToId[addr] == id) {
                return true;
            } else {
                revert ("Mismatch between provided and stored tax ID");
            }        
        } 
        return false;
    }

    // Function that returns the length of a string
    function utfStringLength(string memory str)
        internal
        pure
        returns (uint256 length)
    {
        uint256 i = 0;
        bytes memory string_rep = bytes(str);

        while (i < string_rep.length) {
            if (string_rep[i] >> 7 == 0) i += 1;
            else if (string_rep[i] >> 5 == bytes1(uint8(0x6))) i += 2;
            else if (string_rep[i] >> 4 == bytes1(uint8(0xE))) i += 3;
            else if (string_rep[i] >> 3 == bytes1(uint8(0x1E))) i += 4;
            else i += 1;

            length++;
        }
    }

    // Returns VAT for each level specified, available to everyone
    function getVatForLevel(uint8 level) public view returns (uint256) {
        require(checkIndexValidity(level), "Invalid index <> 0, 1, 2");
        return gatheredVat[level];
    }

    // Aggregates and returns the total VAT, available to everyone
    function totalVat() public view returns (uint256) {
        return (gatheredVat[0] + gatheredVat[1] + gatheredVat[2]);
    }

    /*
    Returns tax ID of the recipient with the most proceeds along with
    their address and the amount of funds transferred to them. Only
    available to the owner of the contract enforced by the onlyOwner
    modifier.
    */
    function getMaxProceedsPerson()
        public
        view
        onlyOwner
        returns (
            uint256 TaxID,
            address Address,
            uint256 ProceedsForID
        )
    {
        return (
            s_maxProceeds.id,
            s_maxProceeds.addr,
            proceedPerId[s_maxProceeds.id]
        );
    }

    // Checks if the VAT level is in bounds (0,1,2)
    function checkIndexValidity(uint8 index) internal pure returns (bool) {
        return (index == 0 || index == 1 || index == 2);
    }

    // Destroys the contract (permitted only by Owner)
    function destroy() public onlyOwner {
        selfdestruct(payable(owner));
    }

    receive() external payable {}
}
