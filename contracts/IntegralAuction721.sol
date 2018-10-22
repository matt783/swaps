pragma solidity 0.4.25;

import {IERC721} from "./IERC721.sol";
import {IntegralAuction} from "./IntegralAuction.sol";

contract IntegralAuction721 is IntegralAuction {

    function open721(
        bytes _partialTx,
        uint256 _reservePrice,
        uint256 _reqDiff,
        address _asset,
        uint256 _value
    ) public returns (bytes32) {
        require(_value > 0);
        require(IERC721(_asset).transferFrom(msg.sender, address(this), _value));

        // Auction identifier is keccak256 of Seller's parital transaction
        bytes32 _auctionId = keccak256(_partialTx.slice(7, 36));

        // Require unique auction identifier
        require(auctions[_auctionId].state == AuctionStates.NONE, "Auction exists.");

        // Add to auctions mapping
        auctions[_auctionId].state = AuctionStates.ACTIVE;
        auctions[_auctionId].value = _value;
        auctions[_auctionId].asset = _asset;
        auctions[_auctionId].seller = msg.sender;
        auctions[_auctionId].reqDiff = _reqDiff;

        // Increment Open positions
        openPositions[msg.sender] = openPositions[msg.sender].add(1);

        // Emit AuctionActive event
        emit AuctionActive(_auctionId, msg.sender, _asset, _value, _partialTx, _reservePrice, _reqDiff);

        return _auctionId;
    }

    function claim721(
        bytes _tx,
        bytes _proof,
        uint _index,
        bytes _headers
    ) public returns (bool) {
        bytes32 _auctionId = keccak256(_tx.slice(7, 36));
        Auction storage _auction = auctions[_auctionId];
        bytes32 _txid;
        address _bidder;
        uint64 _BTCValue;
        bytes32 _merkleRoot;
        uint256 _diff;

        // Require auction state to be ACTIVE
        require(_auction.state == AuctionStates.ACTIVE, 'Auction has closed or does not exist.');

        (_txid, _bidder, _BTCValue) = checkTx(_tx);
        (_diff, _merkleRoot) = checkHeaders(_headers, _auction.reqDiff);
        checkProof(_txid, _merkleRoot, _proof, _index);

        // Get bidder eth address from OP_RETURN payload bytes
        require(checkWhitelist(_auction.seller, _bidder), 'Bidder is not whitelisted.');

        // Update auction state
        _auction.state = AuctionStates.CLOSED;
        _auction.BTCvalue = _BTCValue;
        _auction.bidder = _bidder;

        distributeERC721(_auctionId);

        // Decrement Open positions
        openPositions[_auction.seller] = openPositions[_auction.seller].sub(1);

        // Emit AuctionClosed event
        emit AuctionClosed(
            _auctionId,
            _auction.seller,
            _auction.bidder,
            _auction.asset,
            _auction.value,
            _BTCValue
        );

        return true;
    }

    function distributeERC721(bytes32 _auctionId) internal returns (bool) {
        // Transfer tokens to bidder
        require(
            IERC721(auctions[_auctionId].asset).transferFrom(
                address(this), auctions[_auctionId].bidder, auctions[_auctionId]._value)
        );

        return true;
    }
}
