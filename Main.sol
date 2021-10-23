//SPDX-License-Identifier: Unlicense
pragma solidity = 0.8.9;

contract Main {
    
    mapping( address => string ) private roles;
    mapping( string => address ) private loginToAddress;
    mapping( address => User ) private addressToUser;
    mapping( string => string ) private loginToPassword;

    mapping ( address => bool ) private ADMIN;
    mapping ( address => bool ) private SHOP;
    
    mapping ( string => Shop ) private shops;
    mapping ( string => User[] ) public sellers;
    mapping ( string => Comment[] ) public comments;
    mapping ( uint => Answer[] ) public answers;
    
    Shop[] public SHOPS;
    
    enum STATE { ADMIN, BANK, SHOP, PROVIDER, SELLER, BUYER, GUEST }
    
    /* STRUCTS */ 
    
    struct User {
        string login;
        address userAddress;
        STATE state;
    }
    
    struct Shop {
        uint id;
        string title;
        address ownerAddress;
    }
    
    struct Comment {
        uint id;
        string body;
        string senderLogin;
        uint like;
        uint dislike;
    }
    
    struct Answer {
        uint id;
        string body;
        string senderLogin;
        uint like;
        uint disklike;
    }
    /* MODIFIERS */
    
    modifier onlyAdmin() {
        require( ADMIN[msg.sender] == true, "Caller must be ADMIN.");
        _;
    }
    
    modifier onlyShop() {
        require( SHOP[msg.sender] == true, "Caller must be SHOP.");
        _;
    }
    
    /* MAIN FUNCTIONS */
    
    constructor() {
        ADMIN[ msg.sender ] = true;
    }
    
    function _getUserRole( string memory _login ) private view returns( STATE ) {
        
        address userAddress = loginToAddress[ _login ];
        
        if( userAddress == address( 0 ) ) {
            return STATE.GUEST;
        }
        else {
            User memory person = addressToUser[ userAddress ];
            return person.state;
        }
        
    }
    
    function getUserInfoByLogin( string memory _login ) public view returns ( User memory ) {
        
        address userAddress = loginToAddress[ _login ];
        
        require( userAddress != address( 0 ), "The user is not registered");
        
        User memory userInfo = addressToUser[ userAddress ];
        return userInfo;
    }

    function getShopList() public view returns ( Shop[] memory ) {
        return SHOPS;
    }
    
    function getAllComments( string memory _shopName ) public view returns ( Comment[] memory ) {
        return comments[ _shopName ];
    }

    function register( string memory _login, string memory _password, string memory _rpassword ) public returns( User memory ) {
        
        require( keccak256( abi.encodePacked( _password ) ) == keccak256( abi.encodePacked( _rpassword ) ), "Passwords do not match.");
        require( keccak256( abi.encodePacked( loginToAddress[ _login ] ) ) == keccak256( abi.encodePacked( address( 0 ) ) ), "User already exists.");
        
        loginToAddress[ _login ] = msg.sender;
        loginToPassword[ _login ] = _password;
        addressToUser[ msg.sender ] = User( _login, msg.sender, STATE.BUYER );
        
        return addressToUser[ msg.sender ];
    }
    
    function auth( string memory _login, string memory _password ) public view returns ( User memory ) {
       
        require ( keccak256( abi.encodePacked( loginToPassword[_login] ) ) != keccak256(abi.encodePacked(  _password ) ), "The username or password is incorrect");
        
        address userAddress =  loginToAddress[ _login ];
        User memory userinfo = addressToUser[ userAddress ];
        
        return userinfo;
    }
    
    /* ONLY ADMIN FUNCTIONS */
    
    function setSellerByLogin( string memory _login, string memory _shopOwnerLogin ) public onlyAdmin {
        address userAddress =  loginToAddress[ _login ];
        User memory userinfo = addressToUser[ userAddress ];
        
        require( userinfo.state == STATE.BUYER, "User must be BUYER.");
        sellers[ _shopOwnerLogin ].push( userinfo );
        addressToUser[ userAddress ].state = STATE.SELLER;
    }
    
    function setBuyerByLogin( string memory _login, string memory _shopOwnerLogin ) public onlyAdmin {
        address userAddress =  loginToAddress[ _login ];
        User memory userinfo = addressToUser[ userAddress ];
        
        require( userinfo.state == STATE.SELLER, "User must be SELLER.");
        User[] storage shopSellers = sellers[ _shopOwnerLogin ];
        
        for ( uint i = 0; i < shopSellers.length; i++ ){
            
            if( keccak256( abi.encodePacked( shopSellers[i].login ) )  == keccak256( abi.encodePacked( _login ) ) ) {
                
                for( uint j = i; j < shopSellers.length - 1; j++) {
                    shopSellers[i] = shopSellers[i + 1];
                }
                shopSellers.pop();
                sellers[ _shopOwnerLogin ] = shopSellers;
                
                continue;
            }
        }
        
        
        addressToUser[ userAddress ].state = STATE.BUYER;
    }
    
    function changeMyStatus( STATE _state ) public onlyAdmin {
        addressToUser[ msg.sender ].state = _state;
    }
    
    function createAdmin( string memory _login ) public onlyAdmin {
        address userAddress =  loginToAddress[ _login ];
        addressToUser[ userAddress ].state = STATE.ADMIN;
        ADMIN[ userAddress ] = true;
    }
    
    function deleteAdmin( string memory _login ) public onlyAdmin {
        address userAddress =  loginToAddress[ _login ];
        addressToUser[ userAddress ].state = STATE.BUYER;
        ADMIN[ userAddress ] = false;
    }
    
    function createShopByLogin ( string memory _login ) public onlyAdmin {
        
        address userAddress =  loginToAddress[ _login ];
        
        shops[ _login ] = Shop( SHOPS.length, _login, userAddress );
        SHOPS.push(  shops[ _login ] );
        
        addressToUser[ userAddress ].state = STATE.SHOP;
        SHOP[ userAddress ] = true;
    }
    
    function deleteShopByLogin ( string memory _login ) public onlyAdmin {
        
        address userAddress =  loginToAddress[ _login ];
        addressToUser[ userAddress ].state = STATE.BUYER;
        
        Shop memory shop = shops[ _login ];
        delete shops[ _login ];
        
        for( uint i = shop.id; i < SHOPS.length - 1; i++) {
            SHOPS[i] = SHOPS[i + 1];
        }
        SHOPS.pop();
        
        SHOP[ userAddress ] = false;
    }
    
    /* ONLY BUYER */
    
    function makeComment( string memory _shopName, string memory _comment ) public {
        User memory userinfo = addressToUser[ msg.sender ];
        
        if( userinfo.state == STATE.BUYER ) {
            comments[ _shopName ].push( Comment( block.timestamp, _comment, userinfo.login, 0, 0) );
        }
    }
    
    function makeAnswer( string memory _shopName, uint _commentId, string memory _answer ) public {
        User memory userinfo = addressToUser[ msg.sender ];
        User[] memory shopSellers = sellers[ _shopName ];
        
        bool isSeller = false;
        for ( uint i = 0; i < shopSellers.length; i++ ) {
            if( keccak256( abi.encodePacked( shopSellers[i].login ) )  == keccak256( abi.encodePacked( userinfo.login ) ) ) {
                isSeller = true;
            }
        }
        
        if( userinfo.state == STATE.BUYER || isSeller ) {
            answers[ _commentId ].push( Answer( answers[ _commentId ].length, _answer, userinfo.login, 0, 0 ) );
        }
    }
}