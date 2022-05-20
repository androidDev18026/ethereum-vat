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
    // Array to store 3 VAT levels specified (24%, 13%, 6%)
    uint8[3] public taxes;
    // List of goverment controlled addresses for each level
    address[] private govAddresses;
    // Array to store accumulated VAT for each level
    uint256[3] public gatheredVat;

    /* 
    Store proceeds for each person/address that receives
    funds as an associative array mapping TaxID's to
    Wei's
    */

    struct VatLevels {
        uint8 high;
        uint8 mid;
        uint8 low;
    }

    // To store the person/address with the most proceeds
    struct MaxProceeds {
        uint256 id;
        address addr;
        uint256 myProceeds;
    }

    // The owner that deploys the contract
    address public owner;
    VatLevels public vatLevels = VatLevels(24, 13, 6);

    /* 
    Declare struct to store information about the
    recipient with the most proceeds, make sure it's
    private so that a getter method is not exposed
    */
    MaxProceeds[] private s_MaxProceeds;
    uint256 private m_maxIndex;
    uint256 private maxProceeds;

    // Max amount that VAT doesn't apply to (0.05 ETH -> Wei)
    uint256 public constant MAX_NONVAT = 50000000000000000;
    uint16 public constant MAX_SENTENCE_LENGTH = 80;

    // Define constructor that accepts 3 gov. addresses
    constructor(address[] memory addresses) {
        // Make sure the deployed contract has 3 goverment addresses
        require(
            addresses.length >= 3,
            "Goverment addresses must be at least 3"
        );
        // Owner of the contract is the one deploying it
        owner = msg.sender;
        // Initialize proceeds
        maxProceeds = 0;
        // Initialize each of the 3 arrays defined with values
        taxes = [vatLevels.high, vatLevels.mid, vatLevels.low];
        // This array is dynamic, no real reason
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
    is <= 0.05 ETH
    */
    function sendFunds(address destination) public payable costs(MAX_NONVAT) {
        // Make sure sender has the funds
        require(getBalance(msg.sender) > msg.value, "Insufficient funds");

        // Transfer the funds without taking VAT into account
        payable(destination).transfer(msg.value);
        emit LogMsg1(destination, msg.value);
    }

    /* 
    Transfer funds from one address to another given that all prerequisites
    are met, meaning that the sender has the needed funds and a valid VAT level
    is passed as argument
    */
    function sendFunds(
        address destination,
        uint256 taxId,
        uint8 idx
    ) public payable {
        require(checkIndexValidity(idx), "Invalid index, [0, 1, 2] available");
        require(getBalance(msg.sender) > msg.value, "Insufficient funds");

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
        (int256 indexRetured, uint256 currentProceeds) = updateProceeds(
            destination,
            taxId,
            msg.value,
            tax
        );

        // update the index of receipient with most proceeds in our struct
        updateBestIndex(indexRetured, currentProceeds);

        // Update the total VAT for that level
        gatheredVat[idx] += tax;

        // Emit event if transaction is successful
        emit LogMsg2(destination, msg.value, idx);
    }

    // Same as function above with the added functionality of adding comment
    function sendFunds(
        address destination,
        uint256 taxId,
        uint8 idx,
        string memory comment
    ) public payable {
        require(checkIndexValidity(idx), "Invalid index, [0, 1, 2] available");
        require(getBalance(msg.sender) > msg.value, "Insufficient funds");
        // Make sure the comment is not over the character limit
        require(
            utfStringLength(comment) <= MAX_SENTENCE_LENGTH,
            "Comment >80 characters"
        );

        uint256 tax = (msg.value * taxes[idx]) / 100;

        payable(destination).transfer(msg.value - tax);
        payable(govAddresses[idx]).transfer(tax);

        // Update the proceeds of recipient with the current amount - tax
        (int256 indexRetured, uint256 currentProceeds) = updateProceeds(
            destination,
            taxId,
            msg.value,
            tax
        );

        // update the index of receipient with most proceeds in our struct
        updateBestIndex(indexRetured, currentProceeds);

        gatheredVat[idx] += tax;

        emit LogMsg3(destination, msg.value, idx, comment);
    }

    function updateProceeds(
        address destination,
        uint256 id,
        uint256 amount,
        uint256 tax
    ) private returns (int256, uint256) {
        int256 foundAddressIndex = searchAddress(destination);
        uint256 currentProceeds = 0;
        if (foundAddressIndex != -1) {
            s_MaxProceeds[uint256(foundAddressIndex)].myProceeds +=
                amount -
                tax;
            currentProceeds = s_MaxProceeds[uint256(foundAddressIndex)]
                .myProceeds;
        } else {
            currentProceeds = amount - tax;
            s_MaxProceeds.push(MaxProceeds(id, destination, amount - tax));
        }

        return (foundAddressIndex, currentProceeds);
    }

    function updateBestIndex(int256 indexRetured, uint256 currentProceeds)
        private
    {
        uint256 bestIndex;
        if (currentProceeds > maxProceeds) {
            bestIndex = indexRetured != -1
                ? uint256(indexRetured)
                : s_MaxProceeds.length - 1;
            maxProceeds = currentProceeds;
            m_maxIndex = bestIndex;
        }
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
        assert(checkIndexValidity(level));
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
            s_MaxProceeds[m_maxIndex].id,
            s_MaxProceeds[m_maxIndex].addr,
            s_MaxProceeds[m_maxIndex].myProceeds
        );
    }

    // Checks if the VAT level is in bounds (0,1,2)
    function checkIndexValidity(uint8 index) public pure returns (bool) {
        return (index == 0 || index == 1 || index == 2);
    }

    // Returns the balance of address
    function getBalance(address addr) public view returns (uint256) {
        return addr.balance;
    }

    // Destroys the contract (permitted only by Owner)
    function destroy() public onlyOwner {
        selfdestruct(payable(owner));
    }

    // Search for address in struct
    function searchAddress(address addr) private view returns (int256) {
        for (uint256 i = 0; i < s_MaxProceeds.length; i++)
            if (s_MaxProceeds[i].addr == addr) return int256(i);

        return -1;
    }

    receive() external payable {}
}
