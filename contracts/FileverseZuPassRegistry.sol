// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import "./FileversePortal.sol";
import "./Groth16Verifier.sol";

contract FileverseZuPassRegistry is
    ReentrancyGuard,
    ERC2771Context,
    Groth16Verifier
{
    string public constant name = "Fileverse ZuPass Registry - EthBerlin";
    struct Portal {
        address portal;
        uint256 index;
        uint256 tokenId;
    }

    // Mapping owner address to token count
    mapping(address => uint256) private _balances;
    // Mapping of address of portal with address
    mapping(address => address) private _ownerOf;
    // Mapping from owner to list of hash
    mapping(address => mapping(uint256 => address)) private _ownedPortal;
    // Array with all token ids, used for enumeration
    address[] private _allPortal;
    // Mapping from address of portal to Portal Data
    mapping(address => Portal) private _portalInfo;
    // address of trusted forwarder
    address private immutable trustedForwarder;

    // This us the ETHBerlin event UUID converted to bigint
    uint256[1] VALID_EVENT_IDS = [111560146890584288369567824893314450802];

    // This is hex to bigint conversion for ETHBerlin signer
    uint256[2] ETHBERLIN_SIGNER = [
        13908133709081944902758389525983124100292637002438232157513257158004852609027,
        7654374482676219729919246464135900991450848628968334062174564799457623790084
    ];

    struct ProofArgs {
        uint256[2] _pA;
        uint256[2][2] _pB;
        uint256[2] _pC;
        uint256[38] _pubSignals;
    }

    /**
     * @notice constructor for the fileverse portal registry smart contract
     * Implementation that gets deployed:
     * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/metatx/MinimalForwarder.sol
     * @param _trustedForwarder - instance of the trusted forwarder
     */
    constructor(address _trustedForwarder) ERC2771Context(_trustedForwarder) {
        require(_trustedForwarder != address(0), "FV211");
        trustedForwarder = _trustedForwarder;
    }

    modifier verifiedProof(ProofArgs calldata proof) {
        require(
            this.verifyProof(
                proof._pA,
                proof._pB,
                proof._pC,
                proof._pubSignals
            ),
            "Invalid proof"
        );
        _;
    }

    modifier validEventIds(uint256[38] memory _pubSignals) {
        uint256[] memory eventIds = getValidEventIdFromPublicSignals(
            _pubSignals
        );
        require(
            keccak256(abi.encodePacked(eventIds)) ==
                keccak256(abi.encodePacked(VALID_EVENT_IDS)),
            "Invalid event ids"
        );
        _;
    }

    modifier validSigner(uint256[38] memory _pubSignals) {
        uint256[2] memory signer = getSignerFromPublicSignals(_pubSignals);
        require(
            signer[0] == ETHBERLIN_SIGNER[0] &&
                signer[1] == ETHBERLIN_SIGNER[1],
            "Invalid signer"
        );
        _;
    }

    modifier validWaterMark(uint256[38] memory _pubSignals) {
        require(
            getWaterMarkFromPublicSignals(_pubSignals) ==
                uint256(uint160(msg.sender)),
            "Invalid watermark"
        );
        _;
    }

    /**
     * @notice get function that returns the owner address of the portal
     * @param _portal - The address of the portal
     * @return owner - The address of the owner
     */
    function ownerOf(address _portal) public view returns (address) {
        return _ownerOf[_portal];
    }

    event Mint(address indexed account, address indexed portal);

    /**
     * @notice Create a new FileversePortal contract and assign it to the owner
     * who calls this function
     * @dev This function also emits a Mint event
     * @param _metadataIPFSHash - The IPFS hash of the metadata file.
     * @param _ownerViewDid - owner's view DID
     * @param _ownerEditDid - owner's edit DID
     * @param _proof - proof of ethberlin pcd
     */
    function mint(
        string calldata _metadataIPFSHash,
        string calldata _ownerViewDid,
        string calldata _ownerEditDid,
        ProofArgs calldata _proof
    )
        external
        verifiedProof(_proof)
        validEventIds(_proof._pubSignals)
        validSigner(_proof._pubSignals)
        nonReentrant
    {
        address owner = _msgSender();
        address _portal = address(
            new FileversePortal(
                _metadataIPFSHash,
                _ownerViewDid,
                _ownerEditDid,
                owner,
                trustedForwarder
            )
        );
        _mint(owner, _portal);
        emit Mint(owner, _portal);
    }

    /**
     * @notice A private function that is called by the public function `mint`.
     * It is used to create a new portal and assign it to the owner of the
     * contract.
     * @param _owner - The address of the owner
     * @param _portal - The address of the portal
     */
    function _mint(address _owner, address _portal) private {
        require(_ownerOf[_portal] == address(0), "FV200");
        uint256 length = _balances[_owner];
        uint256 _allPortalLength = _allPortal.length;
        _ownerOf[_portal] = _owner;
        _allPortal.push(_portal);
        _ownedPortal[_owner][length] = _portal;
        _portalInfo[_portal] = Portal(_portal, length, _allPortalLength);
        ++length;
        _balances[_owner] = length;
    }

    /**
     * @notice `portalInfo` returns the `Portal` struct for a given portal address
     * @param _portal - The address of the portal
     * @return portalInfo The Portal memory struct.
     */
    function portalInfo(address _portal) external view returns (Portal memory) {
        return _portalInfo[_portal];
    }

    /**
     * @notice This function returns an array of all the portals in the registry.
     * @param _resultsPerPage results per page
     * @param _page current page
     * @return portals The array of Portal memory struct with all the portals
     */
    function allPortal(
        uint256 _resultsPerPage,
        uint256 _page
    ) external view returns (Portal[] memory) {
        uint256 len = _allPortal.length;
        (uint256 startIndex, uint256 endIndex) = _pagination(
            _resultsPerPage,
            _page,
            len
        );
        Portal[] memory results = new Portal[](endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex; ++i) {
            results[i] = _portalInfo[_allPortal[i]];
        }
        return results;
    }

    /**
     * @notice Returning the number of portals owned by the address _owner
     * @param _owner address of the owner who's balance if being queried
     * @return balance The array of Portal memory struct with all the portals
     */
    function balancesOf(address _owner) public view returns (uint256) {
        return _balances[_owner];
    }

    /**
     * @notice Returning a list of portals that are owned by the address _owner
     * @param _owner address of the owner who's balance if being queried
     * @param _resultsPerPage results per page
     * @param _page current page
     * @return portals The array of Portal memory struct owned by the address _owner
     */
    function ownedPortal(
        address _owner,
        uint256 _resultsPerPage,
        uint256 _page
    ) external view returns (Portal[] memory) {
        uint256 len = balancesOf(_owner);
        (uint256 startIndex, uint256 endIndex) = _pagination(
            _resultsPerPage,
            _page,
            len
        );
        Portal[] memory results = new Portal[](endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex; ++i) {
            results[i] = _portalInfo[_ownedPortal[_owner][i]];
        }
        return results;
    }

    function _pagination(
        uint256 _resultsPerPage,
        uint256 _page,
        uint256 _len
    ) internal pure returns (uint256, uint256) {
        uint256 startIndex = _resultsPerPage * _page - _resultsPerPage;
        uint256 endIndex = Math.min(_resultsPerPage * _page, _len);
        if (startIndex > _len) {
            // overflow prevention
            require(false, "FV212");
        }
        return (startIndex, endIndex);
    }

    // ----------------------------------------------------------
    // Utility functions for destructuring a proof publicSignals|
    // ----------------------------------------------------------

    function getWaterMarkFromPublicSignals(
        uint256[38] memory _pubSignals
    ) public pure returns (uint256) {
        return _pubSignals[37];
    }

    // Numbers of events is arbitary but for this example we are using 10 (including test eventID)
    function getValidEventIdFromPublicSignals(
        uint256[38] memory _pubSignals
    ) public view returns (uint256[] memory) {
        // Events are stored from starting index 15 to till valid event ids length
        uint256[] memory eventIds = new uint256[](VALID_EVENT_IDS.length);
        for (uint256 i = 0; i < VALID_EVENT_IDS.length; i++) {
            eventIds[i] = _pubSignals[15 + i];
        }
        return eventIds;
    }

    function getSignerFromPublicSignals(
        uint256[38] memory _pubSignals
    ) public pure returns (uint256[2] memory) {
        uint256[2] memory signer;
        signer[0] = _pubSignals[13];
        signer[1] = _pubSignals[14];
        return signer;
    }
}
