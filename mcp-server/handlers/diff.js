const fs = require('fs');
const path = require('path');
const os = require('os');

class DiffHandler {
  constructor() {
    this.tempDir = path.join(os.homedir(), '.cache', 'claudecode.vim', 'diff');
    this.activeDiffs = new Map();
    this.ensureTempDirectory();
  }

  ensureTempDirectory() {
    if (!fs.existsSync(this.tempDir)) {
      try {
        fs.mkdirSync(this.tempDir, { recursive: true, mode: 0o700 });
      } catch (error) {
        throw new Error(`Failed to create temp directory: ${error.message}`);
      }
    }
  }

  processDiffRequest(data) {
    const { id, file_path, original_content, modified_content } = data;
    
    if (!id || !file_path || original_content === undefined || modified_content === undefined) {
      throw new Error('Missing required fields in diff request');
    }

    const timestamp = Date.now();
    const fileExt = path.extname(file_path) || '.txt';
    const originalFile = `original_${timestamp}${fileExt}`;
    const modifiedFile = `modified_${timestamp}${fileExt}`;
    
    const tempOriginal = path.join(this.tempDir, originalFile);
    const tempModified = path.join(this.tempDir, modifiedFile);

    try {
      fs.writeFileSync(tempOriginal, original_content, { mode: 0o600 });
      fs.writeFileSync(tempModified, modified_content, { mode: 0o600 });
      
      this.activeDiffs.set(id, {
        tempOriginal,
        tempModified,
        timestamp
      });

      return {
        tempOriginal,
        tempModified
      };
    } catch (error) {
      this.cleanupFiles(tempOriginal, tempModified);
      throw new Error(`Failed to create temp files: ${error.message}`);
    }
  }

  cleanup(id) {
    const diffData = this.activeDiffs.get(id);
    if (diffData) {
      this.cleanupFiles(diffData.tempOriginal, diffData.tempModified);
      this.activeDiffs.delete(id);
    }
  }

  cleanupFiles(...files) {
    files.forEach(file => {
      try {
        if (fs.existsSync(file)) {
          fs.unlinkSync(file);
        }
      } catch (error) {
        console.error(`Error removing file ${file}:`, error);
      }
    });
  }

  cleanupOldFiles(maxAge = 3600000) { // 1 hour in milliseconds
    const now = Date.now();
    
    try {
      const files = fs.readdirSync(this.tempDir);
      
      files.forEach(file => {
        const filePath = path.join(this.tempDir, file);
        const stat = fs.statSync(filePath);
        
        if (now - stat.mtime.getTime() > maxAge) {
          fs.unlinkSync(filePath);
          console.log(`Cleaned up old temp file: ${file}`);
        }
      });
    } catch (error) {
      console.error('Error cleaning up old files:', error);
    }
  }

  getAllActiveDiffs() {
    return Array.from(this.activeDiffs.keys());
  }
}

module.exports = { DiffHandler };