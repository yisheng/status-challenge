pragma solidity ^0.4.18;

import "./PayrollInterface.sol";
import "./Token/EIP20.sol";
import "./Token/ERC223ReceivingContract.sol";
import 'zeppelin-solidity/contracts/ownership/Ownable.sol';

contract Payroll is Ownable, PayrollInterface, ERC223ReceivingContract {
    /* Events */

    event TokenReceived(address from, uint value, bytes data);

    /* Struct & Variables */

    struct Employee {
        address accountAddress;
        address[] allowedTokens;
        uint256[] tokenDistribution; // Sum of token distribution (by %) should be 100%
        uint256 yearlyEURSalary;
        uint256 lastPayDay;
        uint256 lastAllocateDay;
    }

    address public oracle;
    Employee[] public employees;
    address[] public tokens;

    // accountAddress => (employeeId + 1), where `employeeId` starts from `0`.
    // Therefor, `mapping.value == 0` means `address` is not exist.
    mapping(address => uint256) public employeeFlag;

    // tokenAddress => (tokenId + 1), where `tokenId` starts from `0`.
    // Therefor, `mapping.value == 0` means `address` is not exist.
    mapping(address => uint256) public tokenFlag;

    // tokenAddress => tokenRate
    mapping(address => uint256) public tokenRates;

    uint256 ALLOCATE_CYCLE = 180 days; // Just for simplicity
    uint256 PAYOUT_CYCLE = 30 days; // Just for simplicity

    modifier isValidDistribution(uint256[] distribution) {
        uint256 sum = 0;
        for (uint8 i = 0; i < distribution.length; i++) {
            sum += distribution[i];
        }

        require(sum == 100);
        _;
    }

    modifier onlyOracle() {
        require(msg.sender == oracle);
        _;
    }

    modifier onlyEmployee() {
        require(employeeFlag[msg.sender] > 0);
        _;
    }

    modifier onlyEmployeeExist(uint256 employeeId) {
        require(employeeId < employees.length);
        _;
    }

    modifier onlyEmployeeNotExist(address accountAddress) {
        require(employeeFlag[accountAddress] == 0);
        _;
    }

    function() external payable {}

    function Payroll() public {}

    /* OWNER ONLY */

    function addEmployee(
        address accountAddress,
        address[] allowedTokens,
        uint256[] initialTokenDistribution,
        uint256 initialYearlyEURSalary) onlyOwner onlyEmployeeNotExist(accountAddress) isValidDistribution(initialTokenDistribution) public {
        require(accountAddress != address(0));
        require(accountAddress != address(this));
        require(allowedTokens.length == initialTokenDistribution.length);

        Employee memory employee = Employee(accountAddress, allowedTokens, initialTokenDistribution, initialYearlyEURSalary, now, 0);
        uint256 employeeId = employees.push(employee);
        employeeFlag[accountAddress] = employeeId + 1;

        for (uint8 i = 0; i < allowedTokens.length; i++) {
            if (tokenFlag[allowedTokens[i]] == 0) {
                uint256 tokenId = tokens.push(allowedTokens[i]);
                tokenFlag[allowedTokens[i]] = tokenId + 1;
                tokenRates[allowedTokens[i]] = 0;
            }
        }
    }

    function setEmployeeSalary(uint256 employeeId, uint256 yearlyEURSalary) onlyOwner onlyEmployeeExist(employeeId) public {
        employees[employeeId].yearlyEURSalary = yearlyEURSalary;
    }

    function removeEmployee(uint256 employeeId) onlyOwner onlyEmployeeExist(employeeId) public {
        address accountAddress = employees[employeeId].accountAddress;
        delete(employees[employeeId]);
        delete(employeeFlag[accountAddress]);

        // Future Improvement: Payout final salary
    }

    function addFunds() onlyOwner payable public {
        // TODO: Fire an event
    }

    function escapeHatch() onlyOwner public {
        // Send all tokens
        for (uint8 i = 0; i < tokens.length; i++) {
            uint256 balance = EIP20(tokens[i]).balanceOf(this);
            if (balance > 0) {
                EIP20(tokens[i]).transfer(owner, balance);
            }
        }

        // Send Ethers
        owner.transfer(this.balance);
        
        selfdestruct(owner);
    }

    function tokenFallback(address from, uint value, bytes data) public {
        require(tokenFlag[from] > 0);

        // TODO: Fire an event
        TokenReceived(from, value, data);
    }

    function setOracle(address _oracle) onlyOwner public {
        oracle = _oracle;
    }

    /* GETTER */
 
    function getEmployeeCount() onlyOwner public constant returns (uint256) {
        return employees.length;
    }

    function getEmployee(uint256 employeeId) onlyOwner onlyEmployeeExist(employeeId) public constant returns (
        address accountAddress,
        address[] allowedTokens,
        uint256[] tokenDistribution,
        uint256 yearlyEURSalary,
        uint256 lastPayDay,
        uint256 lastAllocateDay
    ) {
        Employee storage employee = employees[employeeId];

        accountAddress = employee.accountAddress;
        allowedTokens = employee.allowedTokens;
        tokenDistribution = employee.tokenDistribution;
        yearlyEURSalary = employee.yearlyEURSalary;
        lastPayDay = employee.lastPayDay;
        lastAllocateDay = employee.lastAllocateDay;
    }
 
    function calculatePayrollBurnrate() onlyOwner public constant returns (uint256) {

    }

    function calculatePayrollRunway() onlyOwner public constant returns (uint256) {

    }

    /* EMPLOYEE ONLY */

    function determineAllocation(address[] tokens, uint256[] distribution) onlyEmployee isValidDistribution(distribution) public {
        uint256 employeeId = employeeFlag[msg.sender] - 1;
        Employee storage employee = employees[employeeId];

        require(tokens.length == distribution.length);
        require(now - employee.lastAllocateDay >= ALLOCATE_CYCLE);

        // Require all tokens are allowed,
        // and arrange the new distribution by the order of `employee.allowedTokens`
        bool isTokenAllowed = false;
        uint256[] memory newDistribution = new uint256[](employee.allowedTokens.length);
        for (uint8 i = 0; i < tokens.length; i++) {
            isTokenAllowed = false;
            for (uint8 j = 0; j < employee.allowedTokens.length; j++) {
                if (tokens[i] == employee.allowedTokens[j]) {
                    isTokenAllowed = true;
                    newDistribution[j] = distribution[i]; // Following `employee.allowedTokens`'s order
                    break;
                }
            }
            require(isTokenAllowed);
        }

        employee.tokenDistribution = newDistribution;
        employee.lastAllocateDay = now;
    }

    function payday() onlyEmployee public {
        uint256 employeeId = employeeFlag[msg.sender] - 1;
        Employee storage employee = employees[employeeId];

        require(now - employee.lastPayDay >= PAYOUT_CYCLE);

        // Require the contract has enough tokens
    }

    /* ORACLE ONLY */
    function setExchangeRate(address token, uint256 eurExchangeRate) public {

    }
}