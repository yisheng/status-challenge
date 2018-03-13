pragma solidity ^0.4.18;

import "./PayrollInterface.sol";
import 'zeppelin-solidity/contracts/ownership/Ownable.sol';

contract Payroll is Ownable, PayrollInterface {
    modifier onlyEmployee() {
        require(msg.sender == owner);
        _;
    }

    function() external payable {}

    function Payroll() public {}

    /* OWNER ONLY */

    function addEmployee(address accountAddress, address[] allowedTokens, uint256 initialYearlyEURSalary) public {

    }

    function setEmployeeSalary(uint256 employeeId, uint256 yearlyEURSalary) public {

    }

    function removeEmployee(uint256 employeeId) public {

    }

    function addFunds() payable public {

    }

    function escapeHatch() public {

    }

    // function addTokenFunds()? // Use approveAndCall or ERC223 tokenFallback
 
    function getEmployeeCount() public constant returns (uint256) {

    }

    function getEmployee(uint256 employeeId) public constant returns (address employee) {

    }
 
    function calculatePayrollBurnrate() public constant returns (uint256) {

    }

    function calculatePayrollRunway() public constant returns (uint256) {

    }

    /* EMPLOYEE ONLY */
    function determineAllocation(address[] tokens, uint256[] distribution) public {

    }

    function payday() public {

    }

    /* ORACLE ONLY */
    function setExchangeRate(address token, uint256 eurExchangeRate) public {

    }
}