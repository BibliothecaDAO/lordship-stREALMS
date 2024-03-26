// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Votes.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Wrapper.sol";

/// The goal of this contract is create a way to allow realm nft holders to get 
/// streamed {x} amount of $lords once they wrap their realms token to obtain vRealms and 
/// they delegate

/// Streams are maintained per address.
/// Whenever a vRealm is sent to any address and the recipient has unclaimed lords, 
/// all unclaimed lords that have been accrued up until that point are automatically 
/// transferred to the recipient and the stream is reset so that the recipient's new vrealms 
/// balance is used for calculating reward 

/// the Flow struct simply maintains the details of the current flow i.e the flow rate of lords (per second)
/// as well as when that flow rate gets expired. A flow rate gets expired when a new one is added. 
/// This means we can change the stream flow rate and when it is changed, everyone's current stream ends 
/// and they only start using the new flow rate when they have claimed their current stream reward

contract RealmLordship is ERC721, EIP712, ERC721Votes, ERC721Wrapper, Ownable2Step {

    event FlowRateUpdated(uint16 indexed id, uint256 rate);
    event RewardTokenUpdated(address indexed oldAddress, address newAddress);
    event RewardPayerUpdated(address indexed oldAddress, address newAddress);

    event RewardClaimed(address indexed recipient, uint256 amount);

    error NotImplemented();

    struct Flow {
        uint256 rate; // flow rate per second
        uint256 endAt;
    }
    mapping(uint16 flowId => Flow) public flows;
    uint16 public currentFlowId;


    struct Stream {
        uint16 flowId;
        uint256 startAt;
    }
    mapping(address owner => Stream) private streams;


    address public rewardTokenAddress;
    address public rewardPayerAddress;

    constructor(
        address _wrappedTokenAddress, 
        address _ownerAddress, 
        uint256 _flowRate, 
        address _rewardTokenAddress, 
        address _rewardPayerAddress
    ) 
        ERC721("vRealm", "vREALM") // todo@confirm name and symbol
        EIP712("vRealm", "1") 
        ERC721Wrapper(IERC721(_wrappedTokenAddress)) 
        Ownable(_ownerAddress)
    {
        // set flow rate   
        _updateFlowRate(_flowRate);

        // update reward meta
         _updateRewardTokenAddress(_rewardTokenAddress);
         _updateRewardPayerAddress(_rewardPayerAddress);
    }

    function updateFlowRate(uint256 rate) public onlyOwner {
        _updateFlowRate(rate);
     }

    function updateRewardTokenAddress(address newRewardTokenAddress) public onlyOwner {
        _updateRewardTokenAddress(newRewardTokenAddress);
     }

    function updateRewardPayerAddress(address newRewardPayerAddress) public onlyOwner {
        _updateRewardPayerAddress(newRewardPayerAddress);
     }

     function currentFlow() public view returns (Flow memory) {
        return flows[currentFlowId];
     }

    function getStream(address owner) public view returns (Stream memory) {
        return streams[owner];
     }

    function claim() public {
        _claimStream(msg.sender);
     }

    function _updateFlowRate(uint256 _flowRate) internal {
        _endCurrentFlow();
        _startNewFlow(_flowRate);
    }

    function _updateRewardTokenAddress(address _rewardTokenAddress) internal {
        emit RewardTokenUpdated(rewardTokenAddress, _rewardTokenAddress);
        rewardTokenAddress = _rewardTokenAddress;
    }

    function _updateRewardPayerAddress(address _rewardPayerAddress) internal {
        emit RewardPayerUpdated(rewardPayerAddress, _rewardPayerAddress);
        rewardPayerAddress = _rewardPayerAddress;
    }



    function _delegate(address account, address delegatee) internal override {
        if (delegatee == address(0)){
            _claimStream(account);
            _endStream(account);
        } else {
            if (delegates(account) == address(0)) {
                _resetStream(account);
            }
        }
        super._delegate(account, delegatee);
    }

    
    function _endCurrentFlow() internal {
        Flow storage flow = flows[currentFlowId];
        flow.endAt = block.timestamp;
    }

    function _startNewFlow(uint256 rate) internal {
        uint16 newFlowId = ++currentFlowId;
        Flow memory newFlow = Flow({rate: rate, endAt: type(uint256).max});
        flows[newFlowId] = newFlow;

        // emit event
        emit FlowRateUpdated(newFlowId, rate);
     }


    /// must be calld before balance updates
    function _claimStream(address owner) internal {
        if (owner != address(0)) {
            Stream storage stream = streams[owner];
            if (stream.flowId != 0 && stream.startAt != 0) {
                Flow storage flow = flows[stream.flowId];
                uint256 endAt;
                if (currentFlowId > stream.flowId) {
                    endAt = flow.endAt;
                } else {
                    endAt = block.timestamp;
                }

                uint256 streamDuration = endAt - stream.startAt;
                uint256 streamedAmount 
                    = _streamedAmount(balanceOf(owner), streamDuration, flow.rate);
                
                // send reward
                if (streamedAmount > 0) {
                    require(
                        IERC20(rewardTokenAddress)
                            .transferFrom(rewardPayerAddress, owner, streamedAmount)
                    );
                    emit RewardClaimed(owner, streamedAmount);
                }

                // reset stream
                _resetStream(owner);
            }
        }
    }

    function _resetStream(address owner) internal {
        if (owner != address(0)) {
            Stream storage stream = streams[owner];
            stream.startAt = block.timestamp;
            stream.flowId = currentFlowId;
        }
    }

    function _endStream(address owner) internal {
        if (owner != address(0)) {
            Stream storage stream = streams[owner];
            stream.startAt = 0;
            stream.flowId = 0;
        }
    }


    function _streamedAmount(uint256 tokenAmount, uint256 streamDuration, uint256 flowRate) 
        internal 
        pure 
        returns (uint256)
    {
        return tokenAmount * streamDuration * flowRate;
     }


    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Votes)
        returns (address)
    {

        // claim stream for both sender and receiver
        _claimStream(_ownerOf(tokenId));
        _claimStream(to);

        address previousOwner = super._update(to, tokenId, auth);
        return previousOwner;
    }


    function _increaseBalance(address, uint128)
        internal
        pure
        override(ERC721, ERC721Votes)
    {
        revert NotImplemented();
    }

}