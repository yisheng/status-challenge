pragma solidity ^0.4.18;

import "./PayrollInterface.sol";
import 'zeppelin-solidity/contracts/ownership/Ownable.sol';

contract Payroll is Ownable, PayrollInterface {
    /* Events */

    /* Struct & Variables */

    struct Employee {
        address accountAddress;
        address[] allowedTokens;
        uint256[] tokenDistribution;
        uint256 yearlyEURSalary;
        uint256 lastPayDay;
        uint256 lastAllocateDay;
    }

    Employee[] employees;
    mapping(address => uint8) employeeMapping;
    address[] tokens;
    mapping(address => uint256) tokenRates;

    modifier onlyEmployee() {
        require(employeeMapping[msg.sender] == 1);
        _;
    }

    modifier onlyEmployeeExist(uint256 employeeId) {
        require(employeeId < employees.length);
        _;
    }

    modifier onlyEmployeeNotExist(address accountAddress) {
        require(employeeMapping[accountAddress] == 0);
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
        require(accountAddress != address(0));
        require(accountAddress != address(this));
        require(allowedTokens.length == initialTokenDistribution.length);

        Employee memory _employee = Employee(accountAddress, allowedTokens, initialTokenDistribution, initialYearlyEURSalary, now, 0);
        employees.push(_employee);
    }

    function setEmployeeSalary(uint256 employeeId, uint256 yearlyEURSalary) onlyOwner public {

    }

    function removeEmployee(uint256 employeeId) onlyOwner public {

    }

    function addFunds() onlyOwner payable public {

    }

    function escapeHatch() onlyOwner public {

    }

    // function addTokenFunds()? // Use approveAndCall or ERC223 tokenFallback

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