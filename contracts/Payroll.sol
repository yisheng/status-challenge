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
        uint256[] tokenDistribution;
        uint256 yearlyEURSalary;
        uint256 lastPayDay;
        uint256 lastAllocateDay;
    }

    address public oracle;
    Employee[] public employees;
    mapping(address => uint8) public employeeFlag;
    address[] public tokens;
    mapping(address => uint8) public tokenFlag;
    mapping(address => uint256) public tokenRates;

    modifier onlyOracle() {
        require(msg.sender == oracle);
        _;
    }

    modifier onlyEmployee() {
        require(employeeFlag[msg.sender] == 1);
        _;
    }

    modifier onlyEmployeeExist(uint256 employeeId) {
        require(employeeId < employees.length);
        _;
    }

    modifier onlyEmployeeNotExist(address accountAddress) {
        require(employeeFlag[accountAddress] != 1);
        _;
    }

    function() external payable {}

    function Payroll() public {}

    /* OWNER ONLY */

    function addEmployee(
        address accountAddress,
        address[] allowedTokens,
        uint256[] initialTokenDistribution,
        uint256 initialYearlyEURSalary) onlyOwner onlyEmployeeNotExist(accountAddress) public {
        // Requirement
        require(accountAddress != address(0));
        require(accountAddress != address(this));
        require(allowedTokens.length == initialTokenDistribution.length);

        // Sum of token distribution (by %) should be 100%
        uint8 i = 0;
        uint256 sumDistribution = 0;
        for (i = 0; i < initialTokenDistribution.length; i++) {
            sumDistribution += initialTokenDistribution[i];
        }
        require(sumDistribution == 100);

        Employee memory employee = Employee(accountAddress, allowedTokens, initialTokenDistribution, initialYearlyEURSalary, now, 0);
        employees.push(employee);
        employeeFlag[accountAddress] = 1;

        for (i = 0; i < allowedTokens.length; i++) {
            if (tokenFlag[allowedTokens[i]] != 1) {
                tokenFlag[allowedTokens[i]] = 1;
                tokenRates[allowedTokens[i]] = 0;
                tokens.push(allowedTokens[i]);
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

        // Improvement: Payout final salary
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
        require(tokenFlag[from] == 1);
        
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

    function determineAllocation(address[] tokens, uint256[] distribution) onlyEmployee public {

    }

    function payday() onlyEmployee public {

    }

    /* ORACLE ONLY */
    function setExchangeRate(address token, uint256 eurExchangeRate) public {

    }
}