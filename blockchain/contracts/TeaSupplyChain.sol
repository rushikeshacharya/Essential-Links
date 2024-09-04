// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import './interfaces/IFarmer.sol';
import './interfaces/IUser.sol';
import './interfaces/IProcessingPlant.sol';
import './interfaces/IShipment.sol';

/**
 * @title SupplyChain
 * @dev Implementation of the supply chain system with user registration and harvest recording.
 */
contract SupplyChain is IUser, IFarmer, IProcessingPlant, IShipment {
  address private immutable admin;

  struct PacketHistory {
    HarvestDetails harvestDetails;
    BatchDetails batchDetails;
    ConsignmentDetails consignmentDetails;
  }
  mapping(address => User) private userDetails;
  mapping(address => string[]) private farmerIdToHarvestIds;
  mapping(string => HarvestDetails) private harvestIdToHarvestDetails;
  mapping(string => ProcessingStatus) private harvestIdToProcessingDetails;
  mapping(string => BatchDetails) private batchIdToBatchDetails;
  mapping(string => ConsignmentDetails) private consignmentIdToConsignmentDetails;
  mapping(string => string) private batchIdsToConsignmentDetails;

  constructor() {
    admin = msg.sender;
  }

  modifier onlyOwner() {
    require(msg.sender == admin, 'Only Admin can perform this action');
    _;
  }

  modifier onlyRole(ROLE role) {
    require(userDetails[msg.sender].role == role, 'You do not have the required role');
    _;
  }

  /**
   * @dev Registers a new user.
   * @param accountAddress Address of the user.
   * @param userId Unique ID of the user.
   * @param role Role of the user in the supply chain.
   */
  function registerUser(address accountAddress, string calldata userId, ROLE role) external override onlyOwner {
    require(accountAddress != address(0), 'Invalid address');
    userDetails[accountAddress] = User({userId: userId, accountAddress: accountAddress, role: ROLE(role), timestamp: block.timestamp});
    emit UserRegistered(accountAddress, userId, role, block.timestamp);
  }

  /**
   * @dev Retrieves the details of a user.
   * @param accountAddress Address of the user.
   * @return The user's details.
   */
  function getUserDetails(address accountAddress) external view override returns (User memory) {
    require(accountAddress != address(0), 'Invalid address');
    return userDetails[accountAddress];
  }

  /**
   * @dev Records a new harvest by the farmer.
   * @param harvestId Unique ID of the harvest.
   * @param date Date of the harvest.
   * @param quality Quality of the harvested leaves.
   * @param quantity Quantity of the harvested leaves.
   * @param location Location of the harvest.
   */
  function recordHarvest(
    string calldata harvestId,
    string calldata date,
    string calldata quality,
    string calldata quantity,
    string calldata location
  ) external override onlyRole(ROLE.FARMER) {
    require(bytes(harvestIdToHarvestDetails[harvestId].harvestId).length == 0, 'Harvest ID already exists');
    _storeHarvest(harvestId, date, quality, quantity, location);
  }

  /**
   * @dev Internal function to store harvest details.
   * @param harvestId Unique ID of the harvest.
   * @param date Date of the harvest.
   * @param quality Quality of the harvested leaves.
   * @param quantity Quantity of the harvested leaves.
   * @param location Location of the harvest.
   */
  function _storeHarvest(
    string memory harvestId,
    string memory date,
    string memory quality,
    string memory quantity,
    string memory location
  ) internal {
    HarvestDetails memory newHarvest = HarvestDetails({
      harvestId: harvestId,
      date: date,
      quality: quality,
      quantity: quantity,
      location: location,
      farmerId: msg.sender,
      timestamp: block.timestamp
    });

    farmerIdToHarvestIds[msg.sender].push(harvestId);
    harvestIdToHarvestDetails[harvestId] = newHarvest;

    emit LeavesHarvested(harvestId, date, quality, quantity, location, msg.sender, block.timestamp);
  }

  /**
   * @dev Retrieves the details of a harvest.
   * @param harvestId Unique ID of the harvest.
   * @return The harvest's details.
   */
  function getHarvestDetails(string calldata harvestId) external view override returns (HarvestDetails memory) {
    require(bytes(harvestIdToHarvestDetails[harvestId].harvestId).length != 0, 'Harvest ID does not exist');
    return harvestIdToHarvestDetails[harvestId];
  }

  /**
   * @dev Records the processing details for a harvest.
   * @param harvestId Unique ID of the harvest.
   * @param status Processing status of the harvest.
   */
  function recordProcessing(string calldata harvestId, ProcessingStatus status) external override onlyRole(ROLE.PROCESSING_PLANT) {
    require(bytes(harvestIdToHarvestDetails[harvestId].harvestId).length != 0, 'Harvest ID does not exist');
    harvestIdToProcessingDetails[harvestId] = status;
    emit ProcessingDetailsUpdated(harvestId, status, block.timestamp);
  }

  /**
   * @dev Retrieves the processing status of a harvest.
   * @param harvestId Unique ID of the harvest.
   * @return The processing status of the harvest.
   */
  function getProcessingStatus(string calldata harvestId) external view override returns (ProcessingStatus) {
    require(bytes(harvestIdToHarvestDetails[harvestId].harvestId).length != 0, 'Harvest ID does not exist');

    return harvestIdToProcessingDetails[harvestId];
  }

  /**
   * @dev Creates a new batch from a harvest.
   * @param batchId Unique ID of the batch.
   * @param harvestId Unique ID of the harvest.
   * @param quantity Quantity of the batch.
   * @param packetIds Array of packet IDs in the batch.
   */
  function createBatch(
    string calldata batchId,
    string calldata harvestId,
    string calldata quantity,
    string[] calldata packetIds
  ) external override onlyRole(ROLE.PROCESSING_PLANT) {
    require(bytes(batchIdToBatchDetails[batchId].batchId).length == 0, 'Batch ID alredy exist');

    batchIdToBatchDetails[batchId].batchId = batchId;
    batchIdToBatchDetails[batchId].harvestId = harvestId;
    batchIdToBatchDetails[batchId].packetQuantity = quantity;
    batchIdToBatchDetails[batchId].timestamp = block.timestamp;

    for (uint256 i = 0; i < packetIds.length; i++) {
      batchIdToBatchDetails[batchId].packetIds.push(packetIds[i]);
    }

    emit BatchCreated(batchId, harvestId, quantity, packetIds, block.timestamp);
    emit PacketsCreated(batchId, packetIds, block.timestamp);
  }

  /**
   * @dev Retrieves the details of a Batch.
   * @param batchId Unique ID of the Batch.
   * @return The Batch details.
   */
  function getBatchDetails(string calldata batchId) external view returns (BatchDetails memory) {
    require(bytes(batchIdToBatchDetails[batchId].batchId).length != 0, 'Batch ID does not exist');

    return batchIdToBatchDetails[batchId];
  }

  /**
   * @dev Creates a new consignment.
   * @param consignmentId Unique ID of the consignment.
   * @param batchIds Array of batch IDs in the consignment.
   * @param carrier Carrier responsible for the consignment.
   * @param departureDate Departure date of the consignment.
   * @param eta Estimated time of arrival of the consignment.
   */
  function createConsignment(
    string calldata consignmentId,
    string[] calldata batchIds,
    string calldata carrier,
    string calldata departureDate,
    string calldata eta
  ) external override onlyRole(ROLE.SHIPMENT) {
    require(bytes(consignmentIdToConsignmentDetails[consignmentId].consignment.consignmentId).length == 0, 'Consignment ID alredy exist');

    // require(consignmentIdToConsignmentDetails[consignmentId].consignment.consignmentId.length == 0, 'Consignment ID already exists');
    consignmentIdToConsignmentDetails[consignmentId].consignment.consignmentId = consignmentId;
    consignmentIdToConsignmentDetails[consignmentId].consignment.carrier = carrier;
    consignmentIdToConsignmentDetails[consignmentId].consignment.departureDate = departureDate;
    consignmentIdToConsignmentDetails[consignmentId].consignment.eta = eta;
    consignmentIdToConsignmentDetails[consignmentId].consignment.timestamp = block.timestamp;
    for (uint256 i = 0; i < batchIds.length; i++) {
      consignmentIdToConsignmentDetails[consignmentId].consignment.batchIds.push(batchIds[i]);
      batchIdsToConsignmentDetails[batchIds[i]] = consignmentId;
    }

    consignmentIdToConsignmentDetails[consignmentId].otherDetails.temperature = '';
    consignmentIdToConsignmentDetails[consignmentId].otherDetails.humidity = '';
    consignmentIdToConsignmentDetails[consignmentId].otherDetails.status = ConsignmentStatus.TRANSIT;
    consignmentIdToConsignmentDetails[consignmentId].otherDetails.timestamp = block.timestamp;

    emit ConsignmentCreated(consignmentId, batchIds, carrier, departureDate, eta, block.timestamp);
  }

  /**
   * @dev Retrieves the details of a consignment.
   * @param consignmentId Unique ID of the consignment.
   * @return The consignment's details.
   */
  function getConsignmentDetails(string calldata consignmentId) external view override returns (ConsignmentDetails memory) {
    require(bytes(consignmentIdToConsignmentDetails[consignmentId].consignment.consignmentId).length != 0, 'Consignment ID does not exist');

    return consignmentIdToConsignmentDetails[consignmentId];
  }

  /**
   * @dev Updates an existing consignment.
   * @param consignmentId Unique ID of the consignment.
   * @param temperature Temperature condition during shipment.
   * @param humidity Humidity condition during shipment.
   * @param status Current status of the consignment.
   */
  function updateConsignment(
    string calldata consignmentId,
    string calldata temperature,
    string calldata humidity,
    ConsignmentStatus status
  ) external override onlyRole(ROLE.SHIPMENT) {
    require(bytes(consignmentIdToConsignmentDetails[consignmentId].consignment.consignmentId).length != 0, 'Consignment ID does not exist');

    // require(consignmentIdToConsignmentDetails[consignmentId].consignment.consignmentId.length > 0, 'Consignment ID does not exist');

    consignmentIdToConsignmentDetails[consignmentId].otherDetails.temperature = temperature;
    consignmentIdToConsignmentDetails[consignmentId].otherDetails.humidity = humidity;
    consignmentIdToConsignmentDetails[consignmentId].otherDetails.status = status;

    emit ConsignmentUpdated(consignmentId, temperature, humidity, status, block.timestamp);
  }

  /**
   * @dev Retrieves the history of packets for a given batch ID.
   * @param batchId The unique identifier of the batch for which the packet history is being queried.
   * @return packetHistory A `PacketHistory` struct containing details of the batch, consignment, and harvest.
   *
   * Requirements:
   * - The `batchId` must be valid and exist in the mappings.
   */
  function getPacketHistory(string calldata batchId) external view returns (PacketHistory memory packetHistory) {
    require(bytes(batchIdToBatchDetails[batchId].batchId).length != 0, 'Batch ID does not exist');

    // Retrieve and set batch details
    packetHistory.batchDetails = batchIdToBatchDetails[batchId];

    // Retrieve and set consignment details based on the batch ID
    string memory consignmentId = batchIdsToConsignmentDetails[batchId];
    packetHistory.consignmentDetails = consignmentIdToConsignmentDetails[consignmentId];

    // Retrieve and set harvest details based on the harvest ID in batch details
    string memory harvestId = packetHistory.batchDetails.harvestId;
    packetHistory.harvestDetails = harvestIdToHarvestDetails[harvestId];

    return packetHistory;
  }
}
