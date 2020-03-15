pragma solidity ^0.5.8;
pragma experimental ABIEncoderV2;//Not for live production, to return array of structs

contract KYC{


// Struct Customer
// uname - username of the customer
// customerData - customer data
// rating - rating given to customer given based on regularity
// upvotes - number of upvotes recieved from banks
// bank - address of bank that validated the customer account
//password- password to see customer details
    struct Customer{
        string uname;
        string customerData;
        uint rating;
        uint upvotes;
        address bank;
        string password;
    }
//struct OrganisationBank
//name -name of the bank
//ethAddress - Ethereum address of the bank/organisation
//rating - rating received from other banks based on number of valid/invalid accounts.
//kyc_count-the number of KYCs verified by the bank/organisation.
//regNumber-the registration number for the bank.
//isAllowed - flag to decide whether the bank can do KYC over the smart contract
    struct OrganisationBank{
        string name;
        address ethAddress;
        uint rating;
        uint kyc_count;
        string regNumber;
        bool isAllowed;
    }
//struct Request
//uname- name of the customer
//bankAddress-unique account address for the bank
//isAllowed- flag to decide whether the bank can do KYC over the smart contract
    struct Request{
        string uname;
        address bankAddress;
        bool isAllowed;
    }
    
    //mapping of all kyc request
    mapping(address=>Request[]) allRequests;
    //mapping of all request to track the bank address and customer
    mapping(address=>mapping(string=>uint256)) allRequestsMapping;
    // Mapping of all valid KYC request
    mapping(address=>mapping(string=>Request)) validKYC;
    //list of all the customer names to iterate over Customer mapping
    string[]customerNames;
    //mapping of all the customer details
    mapping(string => Customer) customers;
    //mapping of all the bank details
    mapping(address => OrganisationBank) banks;
    //list of all the bank address to iterate over the bank mapping
    address[] allBankAddress;
    //mapping to keep track of all the customer access history
    mapping(bytes => address) accessHistory;
    //address of the owner of the blockchain
    address owner;
    //constructor to save the owner of blockchain
    constructor() public{
        owner = msg.sender;
    }
    //modifier isOwner to validate the admin of the blockchain
     modifier isOwner(address _owner) {
       require(owner == _owner,"Admin access required");
       _;
    }
    
     //modifier isValidPassword to validate the admin of the blockchain
     //@params- username and password of the customers
     modifier isValidPassword(string memory userName,string memory _password) {
       require(validatePswd(userName,_password),"Please enter correct password");
       _;
    }
//function to verify passord if present else giving free access 
//@params- username and password of the customers
//@return - true if password matching or password not present
function validatePswd(string memory _uname, string memory _password) internal view returns (bool){
       if(stringsEqual(customers[_uname].password,"")){
           return true;
       }else
       return (stringsEqual(customers[_uname].password,_password));
    }
//function to add the KYC request over the Smart Contract.
//@params-username of the customer and bank address
//Function is made payable as banks need to provide some currency to start of the KYC process
    function addKYCRequest(string memory _userName, address _bankAddress) public payable{
        require(allRequestsMapping[_bankAddress][_userName] == 0,"This user already has done KYC");
        require(banks[msg.sender].isAllowed == true,"This Bank don't have permission to do KYC");
        allRequestsMapping[_bankAddress][_userName] = now;
        allRequests[_bankAddress].push(Request(_userName,_bankAddress,banks[_bankAddress].isAllowed));
        banks[msg.sender].kyc_count++;
        }


//function to add customer
//@params- user name and hash of the customer data
//@return- this function returns 0 if customer added successfully else this return 1 if the Username for the customer is already present
    function addCustomer(string memory _uname, string memory _customerData) public payable returns (int){
        if(!stringsEqual(customers[_uname].uname,_uname)){
            customers[_uname].uname = _uname;
            customers[_uname].customerData = _customerData;
            customers[_uname].bank = msg.sender;
            customerNames.push(_uname);
            addHistory(_uname);
            return 0;
        }
        else
            return 1;
        }


//function to view customer details
//@params- username of the customer and password of the customer
//@return customer name
    function viewCustomer(string memory _uname,string memory _password)public isValidPassword(_uname,_password) view returns(string memory uname,string memory customerData,uint rating,uint upvotes,address bank){
        require(stringsEqual(customers[_uname].uname,_uname),"Customer does not exist");
        return (customers[_uname].uname,customers[_uname].customerData,customers[_uname].rating,customers[_uname].upvotes,customers[_uname].bank);
    }


//function to modify customer data hash
//@params - username of the customer and hash of the customer data
//@return - This function return 0 if the update is successfull else returns 1 if customer not present
     function updateCustomer(string memory _uname,string memory _dataHash) public returns(uint){
        if(stringsEqual(customers[_uname].uname,_uname)){
            customers[_uname].customerData = _dataHash;
            customers[_uname].bank = msg.sender;
            addHistory(_uname);
            return 0;
        }
    return 1;
    }

//function to remove customer
//@params - user name of the customer
//@return - This function return 0 if the removal is successfull else returns 1 if customer not present
    function removeCustomer(string memory _uname) public returns(uint){
    if(stringsEqual(customers[_uname].uname,_uname)){
      delete customers[_uname];
      addHistory(_uname);
      for(uint i = 0;i < customerNames.length;i++){
                if(stringsEqual(customerNames[i],_uname)){
                    for(uint j = i+1;j < customerNames.length; ++j ){
                        customerNames[j-1] = customerNames[j];
                    }
                }
        }
            customerNames.length --;
            addHistory(_uname);
        return 0;
    }
    return 1;
    }


    //function fetch the KYC requests for a specific bank.
    //@param -address of the bank
    //@return -list of all the bank requests
    function getBankRequest(address _bankAddress)  external returns(Request[] memory){
            require(allRequests[_bankAddress].length>0,"No KYC request available");
                return allRequests[_bankAddress];
            
    }
    
    //function to add votes to provide ratings on Customer
    //@param - address of the bank
    //@return - This function return 0 if successfully added the rating else returns 1 if bank not present
    function addRatingToBank(address _bankAddress)public returns(uint){
         require(_bankAddress != msg.sender,"Self rating not allowed, banks can rate only other banks");
         if(banks[_bankAddress].ethAddress == _bankAddress){
            banks[_bankAddress].rating++;
            return 0;
         }
         else
         return 1;
    }

//function to add votes to provide ratings on bank
//@params - user name of the customer
//@return - This function return 0 if successfully added the rating else returns 1 if customer not present
    function addRatingToCustomer(string memory _userName)public returns(uint) {
        require(stringsEqual(customers[_userName].uname,_userName),"Customer does not exist");
          if(stringsEqual(customers[_userName].uname,_userName)){
            customers[_userName].rating++;
            addHistory(_userName);
            return 0;
          }
          else
          return 1;
    }

    //function to fetch customer rating
    //@params - user name of the customer
    //@return -rating of the customer
    function getCustomerRating(string memory _userName)public view returns(uint) {
        require(stringsEqual(customers[_userName].uname,_userName),"Customer does not exist");
        return customers[_userName].rating;
    }

    //function to fetch bank rating
    //@params - address of the bank
    //@return -rating of the bank
    function getBankRating(address _bankAddress)public view returns(uint) {
                require(banks[_bankAddress].ethAddress == _bankAddress,"Bank does not exist");
                return banks[_bankAddress].rating;
    }
    
    //function to fetch the bank details which made the last changes to the customer data
    //@param - user name of the customer
    //@return -Bank address is returned from the function
    function getCustomerAccessHistory(string memory _userName)public view returns(address) {
      bytes memory b = bytes(_userName);
        return accessHistory[b];
    }
    
    //function to set a password for customer data
    //@param - user name of the customer and password
    //@return -This function return 0 if successfully added the password else returns 1 if customer not present
     function setPassword(string memory _userName,string memory _password )public returns(uint) {
         if(stringsEqual(customers[_userName].uname,_userName)){
            customers[_userName].password = _password;
            return 0;
         }
         return 1;
    }
    
    //function to fetch the customer’s own data
    //@param - user name of the customer and password to verify access
    //@return hash of the customer data
    function viewCustomerData(string memory _userName,string memory _password)public isValidPassword(_userName,_password) view returns(string memory){
        require(stringsEqual(customers[_userName].uname,_userName),"Customer does not exist");
            return customers[_userName].customerData;
            
    }
    
    //function to get bank address
    //@param- bank name
    //@return address of the bank
    function getBankAddress(string memory _bankName)public view returns(address){
        for(uint i = 0;i < allBankAddress.length; i++){
                if(stringsEqual(banks[allBankAddress[i]].name,_bankName)){
                    return banks[allBankAddress[i]].ethAddress;
                }
            }
    }
    //function to fetch bank address
    //@param - address of the bank
    //@return - name of the bank
    function getBankName(address _bankAddress)public view returns(string memory){
        require(banks[_bankAddress].ethAddress == _bankAddress,"Bank does not exist");
        return banks[_bankAddress].name;
    }

//function to add bank by admin
//@param - Bank name , bank address and bank registration number
//@return -This function return 0 if successfully added the bank else returns 1 if bank already present
    function addBank(string memory _bankName,address _bankAddress,string memory _regNumber)public isOwner(msg.sender) returns(uint)  {
         if(banks[_bankAddress].ethAddress != _bankAddress){
            banks[_bankAddress].name = _bankName;
            banks[_bankAddress].ethAddress = _bankAddress;
            banks[_bankAddress].regNumber = _regNumber;
            if(owner == _bankAddress)
            banks[_bankAddress].isAllowed=true;//owner is always allowed
            
            allBankAddress.push(_bankAddress);
            
            return 0;
         }
         
        return 1;
    }
//function to remove bank by admin
//@param - address of the bank
//@return -This function return 0 if successfully removed the bank else returns 1 if bank not present
    function removeBank(address _bankAddress)public isOwner(msg.sender) returns(uint)  {
         if(banks[_bankAddress].ethAddress == _bankAddress){
            delete banks[_bankAddress];

            for(uint i = 0;i < allBankAddress.length;i++){
                if(allBankAddress[i]==_bankAddress){
                    for(uint j = i+1;j < allBankAddress.length; ++j ){
                        allBankAddress[j-1] = allBankAddress[j];
                    }
                }
            }
            allBankAddress.length --;
            
            return 0;
         }
        return 1;
    }

    //function to allow bank to do KYC over the smart contract.
    //@param - Bank address and a boolean value to mark allow(true) or not(false)
    //@return - This function return 0 if successfully updated the bank else returns 1 if bank not present
    function allowKYCtoBank(address _bankAddress,bool _isAllowed)public isOwner(msg.sender) returns(uint)  {
         if(banks[_bankAddress].ethAddress == _bankAddress){
            banks[_bankAddress].isAllowed = _isAllowed;
            return 0;
         }
        return 1;
    }

//function to modify customer upvotes
//@params username of the customer and positive or negative votes as boolean
//@return 0 if operation is successfull else if customer not present it will return 1 
function updateKYCVotes(string memory _uname, bool ifIncrease) public payable returns(uint){
    if(stringsEqual(customers[_uname].uname,_uname)){
            if(ifIncrease) {
                customers[_uname].upvotes++;
                if(customers[_uname].upvotes>5){
                    addKYC(_uname,customers[_uname].bank);
                }
            }else{
                 customers[_uname].upvotes--;
                if(customers[_uname].upvotes<=5){
                    removeKYC(_uname);
                }
            }
            
            return 0;
        }
    return 1;
    
}

//function to add Valid KYC depend on upvotes
//@params username of the customer and bank address
function addKYC(string memory _uname, address _bankAddress) internal {
        validKYC[_bankAddress][_uname] = Request(_uname,_bankAddress,banks[_bankAddress].isAllowed);
}

//function to remove Valid KYC depend on upvotes
//@params username of the customer 
function removeKYC(string memory _uname) internal {
     for(uint i = 0;i < allBankAddress.length; i++){
                if(stringsEqual(validKYC[allBankAddress[i]][_uname].uname,_uname)){
                    delete validKYC[allBankAddress[i]][_uname];
                }
            }
    
}

    //internal function to compare string
    //@params- two string variables required to be compared
    //@return - true if both the strings are equal else return false
    function stringsEqual(string storage _a, string memory _b) internal view returns (bool){
        bytes storage a = bytes(_a);
        bytes memory b = bytes(_b);
        if(a.length != b.length){
            return false;
        }
        for(uint i = 0; i < a.length ; i++)
        {
            if(a[i]!=b[i])
            return false;
        }
        return true;
    }
    
    //internal function to add customer update history
    //@param - username of the customer
    function addHistory(string memory Uname) internal{
                bytes memory b = bytes(Uname);
                accessHistory[b] = msg.sender;
    }
}   
