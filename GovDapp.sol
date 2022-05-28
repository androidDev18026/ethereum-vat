// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract GovDapp {
    // List of goverment controlled addresses for each level
    address[] private govAddresses;
    // Array to store accumulated VAT for each level
    uint256[3] internal gatheredVat;

    /* 
    Store proceeds for each person/address that receives
    funds as an associative array mapping TaxID's to
    Wei's
    */

    // To store the recipient in a structure
    struct Recipient {
        uint256 id;
        address addr;
        uint256 earnings;
    }

    /*
    maps TaxId's (unique) to Recipients to keep track
    of the one with most proceeds
    */
    mapping (uint256 => Recipient) internal Recipients;

    /* 
    Keep all the VAT levels,
    LOW: 6%,
    MEDIUM: 13%,
    HIGH: 24%
    */
    enum VatLevels { HIGH, MEDIUM, LOW }

    // To store if an address is associated with a Tax ID
    struct AssociatedWithId {
        uint256 id;
        bool isAssociated;
    }

    // Map addresses to tax ids
    mapping(address => AssociatedWithId) internal addressToId;
    /* 
    Keep a list as map of tax ID already in use. This avoids the
    case of having multiple addresses linked to the same Tax ID
    since TaxIDs must be unique
    */
    mapping(uint256 => bool) internal listOfInvalidIds;

    // The owner that deploys the contract
    address public owner;

    // Holds the recipient with the most proceeds
    Recipient private maxProceedsRecipient;

    // Max amount that VAT doesn't apply to (0.05 ETH -> Wei)
    uint256 internal constant MAX_NONVAT = 50000000000000000;
    uint16 internal constant MAX_SENTENCE_LENGTH = 80;

    // Define constructor that accepts list of gov. addresses
    constructor(address[] memory addresses) {
        // Make sure the deployed contract has 3 goverment addresses
        require(addresses.length >= 3, "Goverment addresses must be at least 3");
        // Owner of the contract is the one deploying it
        owner = msg.sender;
        /* 
        The array to store the gov. controlled addresses is dynamic 
        so that in can potentially be extended to store more than 3
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
        
        VatLevels level = setVatLevel(idx);
        Recipient memory recipient;

        // Check for tax id validity
        if (!seenId(destination, taxId)) {
            // Associate address with id if we see them for the 1st time 
            addressToId[destination] = AssociatedWithId(taxId, true);
            // Afterwards, mark this Tax ID as invalid
            listOfInvalidIds[taxId] = true;
            Recipients[taxId] = Recipient(taxId, destination, uint256(0x0));
        } 
        
        recipient = Recipients[taxId];

        // Calculate the tax
        uint256 tax = (msg.value * getVatValue(level)) / 100;

        // First, transfer part of the funds to destination address
        payable(recipient.addr).transfer(msg.value - tax);
        /* 
        Then, make a tax payment to the goverment controlled address
        for that level
        */
        payable(govAddresses[uint8(level)]).transfer(tax);

        // Update the proceeds of recipient with the current amount - tax
        recipient.earnings += msg.value - tax;
        // Update the total VAT for that level
        gatheredVat[uint8(level)] += tax;

        /*
        Check if the user with the most proceeds has changed
        after this transaction and update the struct accordingly.
        */
        if (recipient.earnings > maxProceedsRecipient.earnings) {
            maxProceedsRecipient = recipient;
        }

        // update the recipients' properties in the map 
        Recipients[taxId] = recipient;

        // Emit event if transaction is successful
        emit LogMsg2(recipient.addr, msg.value, idx);
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

        VatLevels level = setVatLevel(idx);
        Recipient memory recipient;
        
        require(
            utfStringLength(comment) <= MAX_SENTENCE_LENGTH,
            "Comment > 80 characters long"
        );

        // Check for tax id validity
        if (!seenId(destination, taxId)) {
            // Associate address with id if we see them for the 1st time 
            addressToId[destination] = AssociatedWithId(taxId, true);
            // Afterwards, mark this Tax ID as invalid
            listOfInvalidIds[taxId] = true;
            Recipients[taxId] = Recipient(taxId, destination, uint256(0x0));
        } 
        recipient = Recipients[taxId];

        // Calculate the tax
        uint256 tax = (msg.value * getVatValue(level)) / 100;

        // First, transfer part of the funds to destination address
        payable(recipient.addr).transfer(msg.value - tax);
        /* 
        Then, make a tax payment to the goverment controlled address
        for that level
        */
        payable(govAddresses[uint8(level)]).transfer(tax);

        // Update the proceeds of recipient with the current amount - tax
        recipient.earnings += msg.value - tax;
        // Update the total VAT for that level
        gatheredVat[uint8(level)] += tax;

        /*
        Check if the user with the most proceeds has changed
        after this transaction and update the struct accordingly.
        */
        if (recipient.earnings > maxProceedsRecipient.earnings) {
            maxProceedsRecipient = recipient;
        }
        
        // update the recipients' properties in the map 
        Recipients[taxId] = recipient;

        emit LogMsg3(recipient.addr, msg.value, idx, comment);
    }

    function seenId(address addr, uint256 id) internal view returns (bool) {
        // check if address is already associated with a tax ID
        if (addressToId[addr].isAssociated) {
            // in case they match, OK
            if (addressToId[addr].id == id) {
                return true;
            } else {
                revert ("Mismatch between provided and stored tax ID");
            }        
        } else {
            /*
            If this is the 1st time the contract sees this address check
            whether the provided tax ID has not been associated with
            another address already, if the latter case is false revert
            */
            if (listOfInvalidIds[id]) {
                revert ("Tax ID is already reserved for another address, check your input");
            }
            return false;
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
    function getVatForLevel(VatLevels level) public view returns (uint256) {
        return gatheredVat[uint8(level)];
    }

    // Aggregates and returns the total VAT, available to everyone
    function totalVat() public view returns (uint256) {
        return gatheredVat[0] + gatheredVat[1] + gatheredVat[2];
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
            maxProceedsRecipient.id,
            maxProceedsRecipient.addr,
            maxProceedsRecipient.earnings
        );
    }

    function getVatValue(VatLevels level) internal pure returns (uint8) {
        if (level == VatLevels.LOW) {
            return 6;
        } else if (level == VatLevels.MEDIUM) {
            return 13;
        } else {
            return 24;
        }
    }

    function setVatLevel(uint8 index) internal pure returns(VatLevels){
        if (index == 0) return VatLevels.HIGH;
        if (index == 1) return VatLevels.MEDIUM;
        if (index == 2) return VatLevels.LOW;

        revert ("Invalid index provided, [0,1,2] available");
    }

    // Checks if the VAT level is in bounds (0,1,2)
    function checkIndexValidity(VatLevels level) internal pure returns (bool) {
        return (uint8(level) == 0 || uint8(level) == 1 || uint8(level) == 2);
    }

    // Destroys the contract (permitted only by Owner)
    function destroy() public onlyOwner {
        selfdestruct(payable(owner));
    }

    receive() external payable {}
}
