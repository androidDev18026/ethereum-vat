# ethereum-vat

<img src="https://d33wubrfki0l68.cloudfront.net/fcd4ecd90386aeb50a235ddc4f0063cfbb8a7b66/4295e/static/bfc04ac72981166c740b189463e1f74c/40129/eth-diamond-black-white.jpg" width="300" height="250">

# Aristotle University of Thessaloniki
## Data & Web Science MSc Program
### ***Decentralized Technologies Course***
#### Assignment 2, 2022 - Ethereum

### For this assignment you will need to implement a smart contract in Solidity, using the Ethereum blockchain.Your government has decided to prohibit all blockchain transactions, unless they are conducted through a smart contract that will report all transactions to them. **Your task is to write this smart contract.**

#### When a user wants to send some funds to another user, or any address for that matter,instead of sending them directly to the recipient, they will use the smart contract. A part of the funds that will be transferred will be withheld for VAT purposes. In order to accomplish that, you will need to code a contract that when deployed, will accept a list of (government controlled) addresses, where VAT proceeds will be transferredto. Each of the addresses will correspond to one of the different available levels of VAT (24%, 13%, 6%).

#### For facilitating the transfer of funds, you will code three different variations of the same method. The users that would want to transfer funds, will then make their payments by sending funds to these methods.

- [X] The first variation will facilitate transfers of small amounts between individuals. This
shouldn't normally require a VAT transaction, such as a parent giving allowance to their
children. These kinds of transactions should be limited to 0.05 ETH. The method will only
accept a destination address. The method should redirect the total amount of the
transaction to the recipient's address, without making any VAT payments.
- [X] In the second variation, the method that facilitates the payments, will accept a
destination address, the recipient's tax identification number, as well as an index number
corresponding to the appropriate VAT level (0 is the index for 24% VAT, 1 for 13% and 2 for
6%). The method should redirect the appropriate amount of funds to the respective
government address, while transferring the rest to the destination address. The contract
should make appropriate checks if the user that originated the transfer has sufficient
funds and if the VAT index number that is provided is a valid one.
- [X] In the third variation, the method will additionally accept a comment from the sender,
compared to the second variation. In addition to the checks that the previous variation
performs, in this case, it should also check that the provided comment is no longer than
80 characters.
- [X] The contract should keep track of the total amount gathered for each VAT level (in wei) and provide means for any interested party to access that information, for each VAT level separately, but also collectively.
- [X] The contract should also keep track of who the recipient with the largest proceeds is, identified by their tax identification number and address, along with the total amount they received. This information should be available with a single call to one method in the contract. It should also be available only to the user that deployed the contract.
- [X] When a fund transfer has been made through the contract, an event transmitting the
address of the recipient, the total amount transferred and the VAT level used, along with
any provided comment (if applicable) should be emitted.
- [X] You will also have to provide some means to destroy the contract and render it unusable.
This functionality should be available only to the user that deployed the contract.

## TODO
- [X] Add comments
- [X] Remove check balance
- [X] ~~Add check for tax ID's (ID = 0 not allowed)~~
- [X] ~~Add struct for printing person with most proceeds~~

*Notes*:

● Use method overloading for providing the three different variations of the same
method that facilitates the transfer of funds. <br>
● Use a modifier to restrict access to functionality. <br>
● The addresses that correspond to the different VAT levels should not be publicly
available. <br>
● Your submissions should include only the .sol file with the smart contract. <br>
● Comment your code detailing your design choices. <br>
● Submit only the .sol source code file inside a compressed archive (.zip, .tar.gz etc) <br>
