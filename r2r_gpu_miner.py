#!/usr/bin/env python3
"""
R2R GPU Mining Client
Supports NVIDIA CUDA and AMD OpenCL/HIP
Compatible with: RTX 3060/3070/3080/3090/4060/4070/4080/4090
                 RX 5700 XT / 6700 XT / 6800 XT / 6900 XT / 7900 XTX
"""

import json
import hashlib
import time
import threading
import argparse
from web3 import Web3
from web3.contract import Contract
from eth_account import Account
import logging

# GPU Mining imports (will be compiled from .cu and .cl)
try:
    import pycuda.driver as cuda
    import pycuda.autoinit
    HAS_CUDA = True
except ImportError:
    HAS_CUDA = False

try:
    import pyopencl as cl
    HAS_OPENCL = True
except ImportError:
    HAS_OPENCL = False

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# R2R Contract ABI (simplified)
R2R_CONTRACT_ABI = json.loads("""[
    {
        "type": "function",
        "name": "submitShare",
        "inputs": [
            {"name": "nonce", "type": "uint256"},
            {"name": "difficulty", "type": "uint256"}
        ],
        "outputs": [{"name": "", "type": "bool"}]
    },
    {
        "type": "function",
        "name": "pendingReward",
        "inputs": [{"name": "miner", "type": "address"}],
        "outputs": [{"name": "", "type": "uint256"}]
    },
    {
        "type": "function",
        "name": "claimRewards",
        "inputs": [],
        "outputs": []
    }
]""")

class R2RMiningClient:
    def __init__(self, config_file: str):
        with open(config_file, 'r') as f:
            self.config = json.load(f)
        
        # Initialize Web3
        self.w3 = Web3(Web3.HTTPProvider(self.config['rpc_url']))
        if not self.w3.is_connected():
            raise Exception(f"Failed to connect to {self.config['rpc_url']}")
        
        # Load mining contract
        self.contract = self.w3.eth.contract(
            address=Web3.to_checksum_address(self.config['mining_contract']),
            abi=R2R_CONTRACT_ABI
        )
        
        # Miner account
        self.account = Account.from_key(self.config['private_key'])
        self.miner_address = self.account.address
        
        logger.info(f"Miner address: {self.miner_address}")
        
        # GPU Setup
        self.gpu_type = self._detect_gpu()
        self.gpu_devices = self._init_gpu()
        
        # Mining stats
        self.shares_submitted = 0
        self.shares_accepted = 0
        self.total_rewards = 0
        self.mining_active = True
        
    def _detect_gpu(self) -> str:
        """Detect available GPU type"""
        if HAS_CUDA:
            cuda.init()
            count = cuda.Device.count()
            if count > 0:
                logger.info(f"Detected {count} NVIDIA GPU(s)")
                return "CUDA"
        
        if HAS_OPENCL:
            platforms = cl.get_platforms()
            if platforms:
                logger.info(f"Detected {len(platforms)} OpenCL platform(s)")
                return "OpenCL"
        
        raise Exception("No compatible GPU detected. Install CUDA Toolkit or OpenCL drivers.")
    
    def _init_gpu(self) -> list:
        """Initialize GPU devices"""
        devices = []
        
        if self.gpu_type == "CUDA":
            cuda.init()
            for i in range(cuda.Device.count()):
                device = cuda.Device(i)
                devices.append({
                    'id': i,
                    'device': device,
                    'name': device.name().decode(),
                    'compute_capability': f"{device.compute_capability()[0]}.{device.compute_capability()[1]}"
                })
                logger.info(f"GPU {i}: {devices[-1]['name']} (Compute: {devices[-1]['compute_capability']})")
        
        elif self.gpu_type == "OpenCL":
            for platform in cl.get_platforms():
                for device in platform.get_devices():
                    devices.append({
                        'platform': platform,
                        'device': device,
                        'name': device.name,
                        'device_type': cl.device_type.to_string(device.type)
                    })
                    logger.info(f"GPU: {devices[-1]['name']} ({devices[-1]['device_type']})")
        
        return devices
    
    def get_blockhash(self) -> bytes:
        """Get current block hash"""
        block_number = self.w3.eth.block_number
        block = self.w3.eth.get_block(block_number)
        return block['hash']
    
    def get_mining_difficulty(self) -> int:
        """Get current difficulty from contract"""
        # This would come from the smart contract
        # For now, use a default value
        return self.config.get('default_difficulty', 100)
    
    def calculate_target(self, difficulty: int) -> bytes:
        """Calculate target hash based on difficulty"""
        # target = 2^256 / difficulty
        target_value = (2 ** 256) // max(difficulty, 1)
        return target_value.to_bytes(32, byteorder='big')
    
    def keccak256(self, data: bytes) -> bytes:
        """Compute Keccak256 hash"""
        from Crypto.Hash import keccak
        k = keccak.new(digest_bits=256)
        k.update(data)
        return k.digest()
    
    def mine_gpu(self, device: dict, duration: int = 60):
        """Mine on GPU for specified duration"""
        device_name = device.get('name', 'Unknown')
        logger.info(f"Starting mining on {device_name}")
        
        start_time = time.time()
        nonce = 0
        
        while self.mining_active and (time.time() - start_time) < duration:
            try:
                # Get current block info
                blockhash = self.get_blockhash()
                difficulty = self.get_mining_difficulty()
                target = self.calculate_target(difficulty)
                
                # Prepare mining data
                miner_addr_bytes = bytes.fromhex(self.miner_address[2:])
                
                # Simulate GPU mining (in production, use actual GPU kernels)
                nonce_start = nonce
                nonce_range = 1_000_000
                
                # This is where actual GPU mining happens
                # For CUDA: call cuda_mine() from r2r_cuda_miner.cu
                # For OpenCL: call opencl_mine() from r2r_opencl_miner.cl
                
                valid_nonces = self._simulate_gpu_mining(
                    blockhash, miner_addr_bytes, difficulty, target, nonce_start, nonce_range
                )
                
                nonce += nonce_range
                
                # Submit found shares
                for found_nonce in valid_nonces:
                    self._submit_share(found_nonce, difficulty)
                    self.shares_submitted += 1
                
                # Log stats every 60 seconds
                if int(time.time() - start_time) % 60 == 0:
                    logger.info(f"[{device_name}] Shares: {self.shares_submitted}, "
                              f"Accepted: {self.shares_accepted}, "
                              f"Nonce: {nonce:,}")
                
            except Exception as e:
                logger.error(f"Mining error on {device_name}: {e}")
                time.sleep(1)
    
    def _simulate_gpu_mining(self, blockhash: bytes, miner_addr: bytes, 
                            difficulty: int, target: bytes, 
                            nonce_start: int, nonce_range: int) -> list:
        """Simulate GPU mining (replace with actual GPU kernel calls)"""
        valid_nonces = []
        
        # In production, this would call actual GPU kernels
        # For now, check every 1000th nonce as simulation
        for i in range(0, nonce_range, 1000):
            nonce = nonce_start + i
            
            # Compute Keccak256(blockhash || miner_addr || nonce || difficulty)
            hash_input = blockhash + miner_addr + nonce.to_bytes(4, 'big') + difficulty.to_bytes(4, 'big')
            challenge = self.keccak256(hash_input)
            
            # Check if challenge < target
            if int.from_bytes(challenge, 'big') < int.from_bytes(target, 'big'):
                valid_nonces.append(nonce)
                logger.info(f"Found valid share! Nonce: {nonce}")
        
        return valid_nonces
    
    def _submit_share(self, nonce: int, difficulty: int) -> bool:
        """Submit mining share to smart contract"""
        try:
            # Build transaction
            tx = self.contract.functions.submitShare(nonce, difficulty).build_transaction({
                'from': self.miner_address,
                'gas': 200000,
                'gasPrice': self.w3.eth.gas_price,
                'nonce': self.w3.eth.get_transaction_count(self.miner_address),
            })
            
            # Sign and send transaction
            signed_tx = self.w3.eth.account.sign_transaction(tx, self.config['private_key'])
            tx_hash = self.w3.eth.send_raw_transaction(signed_tx.rawTransaction)
            
            logger.info(f"Share submitted: {tx_hash.hex()}")
            self.shares_accepted += 1
            
            return True
            
        except Exception as e:
            logger.error(f"Failed to submit share: {e}")
            return False
    
    def claim_rewards(self) -> bool:
        """Claim accumulated mining rewards"""
        try:
            # Check pending rewards
            pending = self.contract.functions.pendingReward(self.miner_address).call()
            logger.info(f"Pending rewards: {pending} R2R")
            
            if pending > 0:
                # Build claim transaction
                tx = self.contract.functions.claimRewards().build_transaction({
                    'from': self.miner_address,
                    'gas': 150000,
                    'gasPrice': self.w3.eth.gas_price,
                    'nonce': self.w3.eth.get_transaction_count(self.miner_address),
                })
                
                # Sign and send
                signed_tx = self.w3.eth.account.sign_transaction(tx, self.config['private_key'])
                tx_hash = self.w3.eth.send_raw_transaction(signed_tx.rawTransaction)
                
                logger.info(f"Rewards claimed: {tx_hash.hex()}")
                self.total_rewards += pending
                
                return True
            else:
                logger.info("No pending rewards to claim")
                return False
                
        except Exception as e:
            logger.error(f"Failed to claim rewards: {e}")
            return False
    
    def start_mining(self, duration_hours: float = 24):
        """Start mining on all available GPUs"""
        duration_seconds = duration_hours * 3600
        threads = []
        
        logger.info(f"Starting mining for {duration_hours} hours")
        
        for device in self.gpu_devices:
            thread = threading.Thread(
                target=self.mine_gpu,
                args=(device, duration_seconds),
                daemon=True
            )
            threads.append(thread)
            thread.start()
        
        # Monitor mining progress
        try:
            for thread in threads:
                thread.join()
        except KeyboardInterrupt:
            logger.info("Mining interrupted by user")
            self.mining_active = False
    
    def print_stats(self):
        """Print mining statistics"""
        logger.info(f"\n=== R2R Mining Stats ===")
        logger.info(f"Miner Address: {self.miner_address}")
        logger.info(f"GPU Type: {self.gpu_type}")
        logger.info(f"GPUs: {len(self.gpu_devices)}")
        logger.info(f"Shares Submitted: {self.shares_submitted}")
        logger.info(f"Shares Accepted: {self.shares_accepted}")
        logger.info(f"Total Rewards: {self.total_rewards} R2R")
        logger.info(f"========================\n")

def main():
    parser = argparse.ArgumentParser(description='R2R GPU Mining Client')
    parser.add_argument('--config', default='r2r_mining_config.json', help='Configuration file')
    parser.add_argument('--duration', type=float, default=24, help='Mining duration in hours')
    parser.add_argument('--claim', action='store_true', help='Claim rewards after mining')
    
    args = parser.parse_args()
    
    try:
        client = R2RMiningClient(args.config)
        client.start_mining(duration_hours=args.duration)
        
        if args.claim:
            time.sleep(2)  # Wait for block inclusion
            client.claim_rewards()
        
        client.print_stats()
        
    except Exception as e:
        logger.error(f"Fatal error: {e}")
        return 1
    
    return 0

if __name__ == '__main__':
    exit(main())
