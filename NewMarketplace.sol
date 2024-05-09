// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract New_Marketplace is ReentrancyGuard
{
    enum listingStatus{live,cancelled,bought}
    enum pointStatus{on,off}

    struct Listing
    {
        uint256 pointId; // pointId <=> The point's index in points[]
        address seller;
        uint256 quantity;
        uint256 totalPrice;
        listingStatus status;
    }

    struct Point
    {
        address pointContractAddress;
        string name;
        string symbol;
        pointStatus status;
    }

    Point[] public points;
    mapping (address => uint256) indexOfPointContractAddress;
    Listing[] public listings;
    address public owner;

    event ListingCreated(uint256 indexed id, uint256 _point, address seller, uint256 quantity, uint256 totalPrice);
    event ListingCancelled(uint256 indexed id, address seller);
    event TradeExecuted(uint256 indexed id, uint256 _point, address buyer, uint256 quantity, uint256 totalPrice);
    event NewPoint (uint256 indexed id, string name, string symbol, address pointContractAddress);


    //createListing() errors
    error InvalidParameters(uint256 Entered_pointId, uint256 Entered_quantity, uint256 Entered_totalPrice);
    error NotEnoughTokensToList(uint256 userBalance,uint256 quantityTheyAreTryingToList);
    error ApprovedTokensAreNotEnough(uint256 approvedTokensByUser, uint256 Entered_quantity);
    error ExpiredPoint(uint256 pointId);

    //cancelListing() errors
    error notTheListingOwner(address msgSender);
    error listingIsNotLive(uint256 listingId);

    //buyListing() errors
    error incorrectPayment(uint256 Entered_value,uint256 thePriceOfTheListing);
    

    constructor()
    {
        owner=msg.sender;
    }

    modifier onlyOwner()
    {
        require(msg.sender==owner);
        _;
    } 

    function addPoint(address _point) onlyOwner public
    {
        //Since this is an onlyOwner function no need to implement checks here.
        //A condition must be checked from the UI.
        //The condition is: The point we are trying to add isn't already in the points array.
        //
        //One approach to achieve that is calling the view function "getPoints()" from the UI.
        // The result will be an array of Point(the struct above) objects. We iterate over the these objects and
        // check whether the address of the new point "_point" is equal to any other "pointContractAddress" in points[].
        
        points.push(Point(_point,IERC20Metadata(_point).name(),IERC20Metadata(_point).symbol(),pointStatus.on));

        emit NewPoint(points.length-1, points[points.length-1].name, points[points.length-1].symbol, _point);
    }

    function pointStatusSwitchOff(uint256 _pointId) onlyOwner public
    {
        //This function could be called when the point's token-airdrop ends. (When points don't have value anymore)
        points[_pointId].status=pointStatus.off;
    }
    
    
    

    function createListing(uint256 _pointId, uint256 _quantity, uint256 _totalPrice) external
    {
        //Approval must be asked right before calling this funciton by a user.
        //The amount that we should ask to be approved by the user could be calculated as follows:
        //  1. The user will create a new listing of _ponitId="12". quantity="20". totalprice="1"
        //  2. From the UI, we call "getListings()" view function. This will return all the listings on the platform.
        //  3. We then clean the data we got. we keep the entries that contain:
        //      ( pointId = 12 && seller=msg.sender(listings by this user only) && listingStatus=live )
        //     We end up with a few raws of the table (The LIVE listings done by this exact user (msg.sender), for the points with id=12).
        //  4. We calculate the sum of points (pointId=12) already listed by this user, add 20 (the quantity the user is trying to list), and ask
        //     the user to approve that.
        //  Example: A user already has 3 live listings of pointId=12. The quantities of their listings are 25,18, and 30. User is creating a new
        //           listing of pointId=12 with a quantity of 20. The amount we ask the user to approve the contract to spend is: 25+18+30+20=93 points
 
        //Parameters must be right
        if (_quantity <= 0 || _totalPrice <=0 || _pointId>=points.length)
        {
            revert InvalidParameters(_quantity,_totalPrice,_pointId);
        }
        
        //User must have the Points they are trying to sell
        if (IERC20(points[_pointId].pointContractAddress).balanceOf(msg.sender)<_quantity)
        {
            revert NotEnoughTokensToList(IERC20(points[_pointId].pointContractAddress).balanceOf(msg.sender),_quantity);
        }
        
        // User must allow this contract spending the amount they are trying to sell (at least)
        if (IERC20(points[_pointId].pointContractAddress).allowance(msg.sender,address(this))<_quantity)
        {
            revert ApprovedTokensAreNotEnough(IERC20(points[_pointId].pointContractAddress).allowance(msg.sender,address(this)),_quantity);
        }

        //check for the status of the point before listing
        if (points[_pointId].status==pointStatus.off)
        {
            revert ExpiredPoint(_pointId);
        }

        listings.push(Listing(_pointId,msg.sender, _quantity, _totalPrice, listingStatus.live));
        
        emit ListingCreated(listings.length-1, _pointId, msg.sender, _quantity, _totalPrice);
    }

    function cancelListing(uint256 id) external
    {
        //require (msg.sender==listings[id].seller,"Error - MARKETPLACE.sol - Function:cancelListing - You are not the owner of this listing");
        if (msg.sender!=listings[id].seller)
        {
            revert notTheListingOwner(msg.sender);
        }

        //require (listings[id].status==listingStatus.live,"Error - MARKETPLACE.sol - Function:cancelListing - You can not cancel this listing");
        if (listings[id].status!=listingStatus.live)
        {
            revert listingIsNotLive(id);
        }

        listings[id].status=listingStatus.cancelled;

        emit ListingCancelled(id,msg.sender);
    }

    function buyListing(uint256 id) external payable nonReentrant
    {
        if (listings[id].status!=listingStatus.live) revert listingIsNotLive(id);

        if (msg.value != listings[id].totalPrice) revert incorrectPayment(msg.value,listings[id].totalPrice);


        address POINT=points[listings[id].pointId].pointContractAddress;
        IERC20(POINT).transferFrom(listings[id].seller, msg.sender, listings[id].quantity);

        payable(listings[id].seller).transfer(msg.value);

        listings[id].status = listingStatus.bought;

        emit TradeExecuted(id, listings[id].pointId, msg.sender, listings[id].quantity, msg.value);
    }


    

    function getListings() public view returns (Listing[] memory)
    {
        return listings;
    }

    function getPoints() public view returns (Point[] memory)
    {
        return points;
    }
}
