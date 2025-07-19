const ArweaveBundledDirectoryService = require('../services/arweaveBundledDirectoryService');
const fs = require('fs');
const path = require('path');

class ArweaveBundledDirectoryController {
  constructor() {
    this.service = new ArweaveBundledDirectoryService();
    
    // Bind methods to ensure they're accessible
    this.loadWalletFromFile = this.loadWalletFromFile.bind(this);
    this.createMetadataJSON = this.createMetadataJSON.bind(this);
    this.createBundledDirectory = this.createBundledDirectory.bind(this);
    this.uploadMetadataBundledDirectory = this.uploadMetadataBundledDirectory.bind(this);
    this.estimateBundledDirectoryUploadCost = this.estimateBundledDirectoryUploadCost.bind(this);
    this.getBundledDirectoryInfo = this.getBundledDirectoryInfo.bind(this);
  }

  // Load wallet from file
  loadWalletFromFile() {
    try {
      const walletPath = path.join(process.cwd(), 'wallets', 'arweave_wallet.json');
      
      if (!fs.existsSync(walletPath)) {
        throw new Error('Arweave wallet file not found. Please ensure wallets/arweave_wallet.json exists.');
      }

      const walletData = fs.readFileSync(walletPath, 'utf-8');
      return JSON.parse(walletData);
    } catch (error) {
      throw new Error(`Failed to load wallet: ${error.message}`);
    }
  }

  // Create metadata JSON for a single NFT
  createMetadataJSON(item) {
    // Handle date conversion safely
    let dateValue;
    if (item.date instanceof Date) {
      dateValue = item.date.toISOString();
    } else if (typeof item.date === 'string') {
      try {
        const parsedDate = new Date(item.date);
        dateValue = parsedDate.toISOString();
      } catch (error) {
        dateValue = item.date;
      }
    } else {
      dateValue = new Date().toISOString();
    }

    const host = process.env.ARWEAVE_HOST || 'arweave.net';
    return {
      name: `${item.displayName || item.name} #${item.tokenId}`,
      description: item.description,
      image: `https://${host}/${item.imageTxId}`,
      attributes: [
        { trait_type: "Artist", value: item.artist },
        { trait_type: "Date", value: dateValue },
        { trait_type: "Location", value: item.location },
        { trait_type: "Block", value: item.block },
        { trait_type: "Seat", value: item.seat },
      ],
      ...item.additionalAttributes // Allow custom attributes
    };
  }

  // Create a bundled directory structure with proper file objects
  createBundledDirectory(metadataList) {
    try {
      console.log(`📦 Creating bundled directory structure for ${metadataList.length} metadata items...`);

      // Create files array for bundlr upload
      const files = [];

      // Add all metadata files
      for (let i = 0; i < metadataList.length; i++) {
        const item = metadataList[i];
        
        try {
          console.log(`📝 Processing metadata ${i + 1}/${metadataList.length}: ${item.displayName || item.name}`);
          
          const metadata = this.createMetadataJSON(item);
          const fileName = `${item.tokenId}.json`;
          
          // Create file object for bundlr
          files.push({
            name: fileName,
            data: Buffer.from(JSON.stringify(metadata, null, 2)),
            contentType: 'application/json'
          });
          
          console.log(`✅ Added: ${fileName}`);

        } catch (error) {
          console.error(`❌ Error processing metadata for token ${item.tokenId}:`, error.message);
          throw error;
        }
      }

      console.log(`✅ Bundled directory structure created with ${files.length} files`);
      return files;

    } catch (error) {
      throw new Error(`Failed to create bundled directory: ${error.message}`);
    }
  }

  // Upload NFT metadata as a bundled directory
  async uploadMetadataBundledDirectory(req, res) {
    try {
      const { metadataList, options = {} } = req.body;

      // Validate input
      if (!metadataList || !Array.isArray(metadataList) || metadataList.length === 0) {
        return res.status(400).json({
          success: false,
          error: 'metadataList is required and must be a non-empty array'
        });
      }

      if (metadataList.length > 10000) {
        return res.status(400).json({
          success: false,
          error: 'Collection size too large. Maximum 10,000 tokens per upload. Consider splitting into smaller batches.'
        });
      }

      // Validate each metadata item
      for (let i = 0; i < metadataList.length; i++) {
        const item = metadataList[i];
        const requiredFields = ['tokenId', 'displayName', 'description', 'imageTxId', 'artist', 'date', 'location', 'block', 'seat'];
        
        for (const field of requiredFields) {
          if (!item[field]) {
            return res.status(400).json({
              success: false,
              error: `Missing required field '${field}' in metadata item ${i + 1}`
            });
          }
        }

        // Validate tokenId is a string or number
        if (typeof item.tokenId !== 'string' && typeof item.tokenId !== 'number') {
          return res.status(400).json({
            success: false,
            error: `tokenId must be a string or number in metadata item ${i + 1}`
          });
        }

        // Validate imageTxId format - more flexible for testnet and development
        if (!item.imageTxId || typeof item.imageTxId !== 'string') {
          return res.status(400).json({
            success: false,
            error: `imageTxId must be a non-empty string in metadata item ${i + 1}`
          });
        }
        
        // Allow placeholder values for testing (like "placeholder" or "test")
        if (item.imageTxId === 'placeholder' || item.imageTxId === 'test' || item.imageTxId.startsWith('test_')) {
          console.log(`Warning: Using placeholder imageTxId in metadata item ${i + 1}: ${item.imageTxId}`);
        } else if (!/^[a-zA-Z0-9_-]{20,}$/.test(item.imageTxId)) {
          return res.status(400).json({
            success: false,
            error: `Invalid imageTxId format in metadata item ${i + 1}. Must be at least 20 characters and contain only letters, numbers, hyphens, and underscores.`
          });
        }
      }

      console.log(`Starting bundled directory upload for ${metadataList.length} metadata items...`);

      // Load wallet
      const wallet = this.loadWalletFromFile();
      
      // Create files array for bundled upload
      const files = this.createBundledDirectory(metadataList);
      
      // Upload as bundled directory transaction
      const uploadResult = await this.service.uploadBundledDirectory(files, wallet, options);
      
      console.log('Upload successful:', uploadResult);
      
      return res.status(200).json({
        success: true,
        message: 'NFT metadata uploaded successfully as bundled directory',
        data: {
          ...uploadResult,
          totalFiles: files.length,
          baseURI: `https://arweave.net/${uploadResult.bundleTxId}/`,
          usage: `Access individual metadata at: https://arweave.net/${uploadResult.bundleTxId}/{tokenId}.json`
        }
      });

    } catch (error) {
      console.error('Bundled directory upload error:', error);
      return res.status(500).json({
        success: false,
        error: `Bundled directory upload failed: ${error.message}`
      });
    }
  }

  // Estimate upload costs for bundled directory
  async estimateBundledDirectoryUploadCost(req, res) {
    try {
      const { metadataList } = req.body;

      // Validate input
      if (!metadataList || !Array.isArray(metadataList) || metadataList.length === 0) {
        return res.status(400).json({
          success: false,
          error: 'metadataList is required and must be a non-empty array'
        });
      }

      // Validate each metadata item
      for (let i = 0; i < metadataList.length; i++) {
        const item = metadataList[i];
        const requiredFields = ['tokenId', 'displayName', 'description', 'imageTxId', 'artist', 'date', 'location', 'block', 'seat'];
        
        for (const field of requiredFields) {
          if (!item[field]) {
            return res.status(400).json({
              success: false,
              error: `Missing required field '${field}' in metadata item ${i + 1}`
            });
          }
        }
      }

      // Create files array for cost estimation
      const files = this.createBundledDirectory(metadataList);
      
      // Estimate costs
      const costEstimate = await this.service.estimateUploadCost(files);

      return res.status(200).json({
        success: true,
        message: 'Bundled directory cost estimation completed',
        data: {
          ...costEstimate,
          totalFiles: files.length
        }
      });

    } catch (error) {
      console.error('Cost estimation error:', error);
      return res.status(500).json({
        success: false,
        error: `Cost estimation failed: ${error.message}`
      });
    }
  }

  // Get bundled directory information
  async getBundledDirectoryInfo(req, res) {
    try {
      const { bundleTxId } = req.params;

      if (!bundleTxId) {
        return res.status(400).json({
          success: false,
          error: 'bundleTxId is required'
        });
      }

      // Validate transaction ID format - more flexible for testnet
      if (!/^[a-zA-Z0-9_-]{20,}$/.test(bundleTxId)) {
        return res.status(400).json({
          success: false,
          error: 'Invalid bundle transaction ID format. Must be at least 20 characters and contain only letters, numbers, hyphens, and underscores.'
        });
      }

      // Fetch bundle info from service
      const bundleInfo = await this.service.getBundleInfo(bundleTxId);
      
      return res.status(200).json({
        success: true,
        message: 'Bundled directory information retrieved',
        data: {
          bundleTxId: bundleTxId,
          bundleUrl: `https://arweave.net/${bundleTxId}`,
          baseURI: `https://arweave.net/${bundleTxId}/`,
          arweaveBaseURI: `ar://${bundleTxId}/`,
          ...bundleInfo,
          usage: 'Use the baseURI + tokenId + ".json" to access individual metadata files'
        }
      });

    } catch (error) {
      console.error('Bundled directory info error:', error);
      return res.status(500).json({
        success: false,
        error: `Failed to get bundled directory info: ${error.message}`
      });
    }
  }
}

module.exports = new ArweaveBundledDirectoryController();