# Remix Solidity Unit Testing Example

A basic Solidity unit testing example using Remix IDE testing libraries.

---

# Overview

This project demonstrates how to write and execute Solidity unit tests directly inside Remix IDE using:

* `remix_tests.sol`
* `remix_accounts.sol`

The contract includes:

* Basic assertions
* Equality checks
* Failure examples
* Custom transaction sender testing
* Ether value testing

This repository is intended for educational purposes and Solidity testing practice.

---

# Project Structure

```text
project/
│
├── contracts/
│   └── estakhr.sol
│
├── tests/
│   └── testSuite_test.sol
│
└── README.md
```

---

# Imports Explained

## remix_tests.sol

```solidity
import "remix_tests.sol";
```

Provides the built-in Remix testing framework.

Used for:

* Assertions
* Test execution
* Result reporting

---

## remix_accounts.sol

```solidity
import "remix_accounts.sol";
```

Provides access to Remix virtual testing accounts.

Used for:

* Simulating different wallets
* Custom transaction sender testing
* Transaction value testing

---

## estakhr.sol

```solidity
import "../metarang/estakhr.sol";
```

Imports the target smart contract being tested.

In this example, the test file references an external contract called:

```text
estakhr.sol
```

---

# Test Contract

```solidity
contract testSuite
```

This is the main Solidity testing contract.

Remix automatically detects contracts ending with:

```text
_test.sol
```

and runs all public test functions.

---

# Available Test Lifecycle Hooks

Remix supports special hook functions:

| Function   | Purpose                    |
| ---------- | -------------------------- |
| beforeAll  | Runs once before all tests |
| beforeEach | Runs before every test     |
| afterEach  | Runs after every test      |
| afterAll   | Runs after all tests       |

---

# Test Functions Explained

---

# beforeAll()

```solidity
function beforeAll() public
```

Runs before every other test.

Current example:

```solidity
Assert.equal(uint(1), uint(1), "1 should be equal to 1");
```

Purpose:

* Setup contracts
* Deploy dependencies
* Initialize state

---

# checkSuccess()

```solidity
function checkSuccess() public
```

Demonstrates successful assertions.

Includes:

## Assert.ok()

```solidity
Assert.ok(2 == 2, 'should be true');
```

Checks boolean conditions.

---

## Assert.greaterThan()

```solidity
Assert.greaterThan(uint(2), uint(1));
```

Checks if first value is greater.

---

## Assert.lesserThan()

```solidity
Assert.lesserThan(uint(2), uint(3));
```

Checks if first value is smaller.

---

# checkSuccess2()

```solidity
function checkSuccess2() public pure returns (bool)
```

Simplified test style.

If function returns:

```solidity
true
```

then test passes.

If returns:

```solidity
false
```

then test fails.

Useful for lightweight tests.

---

# checkFailure()

```solidity
function checkFailure() public
```

Intentional failing test example.

```solidity
Assert.notEqual(uint(1), uint(1));
```

This fails because:

```text
1 == 1
```

Purpose:

* Learn Remix failure reporting
* Demonstrate failed assertions

---

# Custom Transaction Context

Remix allows simulation of:

* Different senders
* Ether values

Using special comments:

```solidity
/// #sender: account-1
/// #value: 100
```

---

# checkSenderAndValue()

```solidity
function checkSenderAndValue() public payable
```

Tests:

* Transaction sender
* ETH value sent

Example:

```solidity
Assert.equal(
    msg.sender,
    TestsAccounts.getAccount(1),
    "Invalid sender"
);
```

Checks sender identity.

---

## ETH Value Check

```solidity
Assert.equal(msg.value, 100);
```

Checks sent wei amount.

---

# Running Tests in Remix

## Step 1

Open Remix IDE.

---

## Step 2

Place files in correct folders.

Example:

```text
contracts/
tests/
```

---

## Step 3

Open:

```text
Solidity Unit Testing
```

plugin.

---

## Step 4

Click:

```text
Run
```

---

# Expected Results

You should see:

* Passed tests
* Failed tests
* Gas usage
* Assertion messages

---

# Important Notes

## Compilation Warning

The import:

```solidity
import "remix_accounts.sol";
```

may fail in:

```text
Solidity Compiler
```

plugin.

This is normal.

It works correctly inside:

```text
Solidity Unit Testing
```

plugin.

---

# Common Assertion Methods

| Assertion            | Purpose            |
| -------------------- | ------------------ |
| Assert.ok()          | Boolean condition  |
| Assert.equal()       | Equality           |
| Assert.notEqual()    | Non-equality       |
| Assert.greaterThan() | Greater comparison |
| Assert.lesserThan()  | Smaller comparison |

---

# Educational Goals

This project teaches:

* Solidity testing
* Remix testing workflow
* Assertion handling
* Transaction simulation
* Smart contract QA basics

---

# Future Improvements

Possible upgrades:

* Full contract deployment testing
* Event testing
* Revert testing
* Gas optimization testing
* Access control testing
* ERC20 / ERC721 tests
* Integration testing

---

# Technologies

* Solidity
* Remix IDE
* Remix Unit Testing
* Ethereum Virtual Machine (EVM)

---

# License

GPL-3.0

---

# Author

Parsa Abolhasani Rad

Solidity & Web3 Practice Repository
