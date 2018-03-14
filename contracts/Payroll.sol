pragma solidity ^0.4.18;

import "./PayrollInterface.sol";
import "./Token/EIP20.sol";
import "./Token/ERC223ReceivingContract.sol";
import 'zeppelin-solidity/contracts/ownership/Ownable.sol';

/**
 * @title Status.im payroll contract
 * @author Daniel <yang@desheng.me>
 * @dev Smart contract challenge for status.im
 */
contract Payroll is Ownable, PayrollInterface, ERC223ReceivingContract {
    /* Events */

    event EmployeeAdded(uint256 employeeId, address accountAddress, address[] allowedTokens, uint256[] initialTokenDistribution, uint256 initialYearlyEURSalary);
    event EmployeeRemoved(uint256 employeeId, address accountAddress);
    event EtherReceived(address sender, uint256 value);
    event TokenReceived(address sender, uint256 value, bytes data);
    event BalanceInsufficient(address tokenAddress);
    event PayementFailed(address tokenAddress, uint valueToSend);
    event EscapeHatch();

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

    /* Modifiers */

    modifier isValidDistribution(uint256[] distribution) {
        uint256 sum = 0;
        for (uint8 i = 0; i < distribution.length; i++) {
            sum += distribution[i];
        }

        require(sum == 100);
        _;
    }

    modifier isValidTokenRates {
        for (uint8 i = 0; i < tokens.length; i++) {
            require(tokenRates[i] != 0);
        }
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

    /**
     * @dev Function to add a new employee
     * @param accountAddress The address of employee
     * @param allowedTokens Array of tokens addresses
     * @param initialTokenDistribution Array of token distribution in %, should be sum 100%
     * @param initialYearlyEURSalary The yearly salary in EUR
     */
    function addEmployee(
        address accountAddress,
        address[] allowedTokens,
        uint256[] initialTokenDistribution,
        uint256 initialYearlyEURSalary
    ) onlyOwner onlyEmployeeNotExist(accountAddress) isValidDistribution(initialTokenDistribution) public {
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

        EmployeeAdded(employeeId, accountAddress, allowedTokens, initialTokenDistribution, initialYearlyEURSalary);
    }

    /**
     * @dev Function to set a new salary for a given employee
     * @param employeeId The ID of employee
     * @param yearlyEURSalary The yearly salary in EUR
     */
    function setEmployeeSalary(uint256 employeeId, uint256 yearlyEURSalary) onlyOwner onlyEmployeeExist(employeeId) public {
        employees[employeeId].yearlyEURSalary = yearlyEURSalary;
    }

    /**
     * @dev Function to remove an existing employee
     * @param employeeId The ID of employee
     */
    function removeEmployee(uint256 employeeId) onlyOwner onlyEmployeeExist(employeeId) public {
        address accountAddress = employees[employeeId].accountAddress;
        delete(employees[employeeId]);
        delete(employeeFlag[accountAddress]);

        EmployeeRemoved(employeeId, accountAddress);

        // Future Improvement: Payout final salary
    }

    function addFunds() onlyOwner payable public {
        EtherReceived(msg.sender, msg.value);
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

        EscapeHatch();
        
        selfdestruct(owner);
    }

    function tokenFallback(address sender, uint value, bytes data) public {
        require(tokenFlag[sender] > 0);

        TokenReceived(sender, value, data);
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
        uint256 sum = 0;
        for (uint8 i = 0; i < employees.length; i++) {
            sum += employees[i].yearlyEURSalary;
        }
        return sum;
    }

    function calculatePayrollRunway() onlyOwner public constant returns (uint256) {
        uint256[] memory tokenBalances = new uint256[](tokens.length);
        mapping(address => uint256) tokenYearlyDemands;

        // The balances
        for (uint256 i = 0; i < tokens.length; i++) {
            tokenBalances[i] = EIP20(tokens[i]).balanceOf(this);
            tokenYearlyDemands[tokens[i]] = 0;
        }

        // The demands
        for (uint256 j = 0; j < employees.length; j++) {
            Employee storage employee = employees[j];
            for (uint256 k = 0; k < employee.allowedTokens.length; k++) {
                address tokenAddress = employee.allowedTokens[k];
                uint256 tokenRate = tokenRates[tokenAddress];
                uint256 distribution = employee.tokenDistribution[k];
                tokenYearlyDemands[tokenAddress] += employee.yearlyEURSalary * tokenRate * distribution / 100;
            }
        }

        // The min daysLeft
        uint256 daysLeft = 0;
        for (uint256 l = 0; l < tokens.length; l++) {
            uint256 demand = tokenYearlyDemands[tokens[l]];
            if (demand == 0) {
                continue;
            }

            uint256 temp = tokenBalances[l] / demand * 365;
            if (daysLeft == 0 || temp < daysLeft) {
                daysLeft = temp;
            }
        }

        return daysLeft;
    }

    /* EMPLOYEE ONLY */

    function determineAllocation(address[] _tokens, uint256[] _distribution) onlyEmployee isValidDistribution(_distribution) public {
        uint256 employeeId = employeeFlag[msg.sender] - 1;
        Employee storage employee = employees[employeeId];

        require(_tokens.length == _distribution.length);
        require(now - employee.lastAllocateDay >= ALLOCATE_CYCLE);

        // Require all tokens are allowed,
        // and arrange the new distribution by the order of `employee.allowedTokens`
        bool isTokenAllowed = false;
        uint256[] memory newDistribution = new uint256[](employee.allowedTokens.length);
        for (uint8 i = 0; i < _tokens.length; i++) {
            isTokenAllowed = false;
            for (uint8 j = 0; j < employee.allowedTokens.length; j++) {
                if (_tokens[i] == employee.allowedTokens[j]) {
                    isTokenAllowed = true;
                    newDistribution[j] = _distribution[i];
                    break;
                }
            }
            if (!isTokenAllowed) {
                revert();
            }
        }

        employee.tokenDistribution = newDistribution;
        employee.lastAllocateDay = now;
    }

    function payday() onlyEmployee isValidTokenRates public {
        uint256 employeeId = employeeFlag[msg.sender] - 1;
        Employee storage employee = employees[employeeId];

        require(now - employee.lastPayDay >= PAYOUT_CYCLE);

        // Require the contract has enough tokens
        address tokenAddress;
        uint256 tokenDistribution;
        uint256[] memory tokensToSend = new uint256[](employee.allowedTokens.length);
        for (uint8 i = 0; i < employee.allowedTokens.length; i++) {
            tokenAddress = employee.allowedTokens[i];
            tokenDistribution = employee.tokenDistribution[i];

            if (tokenDistribution > 0) {
                uint256 balance = EIP20(tokenAddress).balanceOf(this);
                uint256 tokenRate = tokenRates[tokenAddress];
                tokensToSend[i] = (employee.yearlyEURSalary / 12) * tokenRate * employee.tokenDistribution[i] / 100;
                if (balance < tokensToSend[i]) {
                    BalanceInsufficient(address tokenAddress);
                    revert();
                }
            }
        }

        // Payout, send the tokens
        for (uint8 j = 0; j < employee.allowedTokens.length; j++) {
            tokenAddress = employee.allowedTokens[j];

            if (tokensToSend[j] > 0) {
                if (!EIP20(tokenAddress).transfer(msg.sender, tokensToSend[j])) {
                    PayementFailed(tokenAddress, tokensToSend[j]);
                }
            }
        }

        employee.lastPayDay = now;
    }

    /* ORACLE ONLY */

    function setExchangeRate(address token, uint256 eurExchangeRate) onlyOracle public {
        require(tokenFlag[token] > 0);
        tokenRates[token] = eurExchangeRate;
    }
}