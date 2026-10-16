# R2R GPU Mining Guide

Повна підтримка видеокарт NVIDIA RTX та AMD RX для майнингу RelaxCoin (R2R).

## 📊 Підтримувані Відеокарти

### NVIDIA RTX (CUDA)
- RTX 3060 (8GB VRAM, Compute 8.6)
- RTX 3070 (8GB VRAM, Compute 8.6)
- RTX 3080 (10GB VRAM, Compute 8.6)
- RTX 3090 (24GB VRAM, Compute 8.6)
- RTX 4060 (8GB VRAM, Compute 8.9)
- RTX 4070 (12GB VRAM, Compute 8.9)
- RTX 4080 (16GB VRAM, Compute 8.9)
- RTX 4090 (24GB VRAM, Compute 8.9)

### AMD RX (OpenCL/HIP)
- RX 5700 XT (8GB VRAM, 40 CUs)
- RX 6700 XT (12GB VRAM, 36 CUs)
- RX 6800 XT (16GB VRAM, 60 CUs)
- RX 6900 XT (16GB VRAM, 80 CUs)
- RX 7900 XTX (24GB VRAM, 96 CUs)

---

## 🔧 Встановлення

### Крок 1: Встановити драйвери GPU

#### NVIDIA
```bash
# Windows: Завантажте від https://www.nvidia.com/Download/driverDetails.aspx
# Linux: 
sudo apt-get update
sudo apt-get install nvidia-driver-530
```

#### AMD
```bash
# Windows: Завантажте AMD Radeon Adrenalin drivers
# Linux:
sudo apt-get install amdgpu-core amdgpu-dkms
```

### Крок 2: Встановити CUDA Toolkit (тільки NVIDIA)

```bash
# Windows: https://developer.nvidia.com/cuda-toolkit-archive
# Linux:
wget https://developer.download.nvidia.com/compute/cuda/11.8.0/local_installers/cuda_11.8.0_linux_x86_64.run
sudo sh cuda_11.8.0_linux_x86_64.run
```

### Крок 3: Встановити OpenCL SDK (для AMD)

```bash
# Windows: https://github.com/RadeonOpenCompute/ROCm
# Linux:
sudo apt-get install rocm-dkms
sudo apt-get install opencl-headers opencl-clhpp-headers
```

### Крок 4: Встановити Python залежності

```bash
# Windows:
pip install -r requirements.txt

# Linux:
pip3 install -r requirements.txt
```

### Крок 5: Скомпілювати GPU ядра

```bash
# Linux:
make cuda        # Тільки для NVIDIA
make opencl      # Тільки для AMD
make all         # Для обох

# Windows (за допомогою Visual Studio):
# 1. Відкрийте x64 Native Tools Command Prompt for Visual Studio
# 2. Запустіть: nvcc -O3 -std=c++14 -shared -o libr2r_cuda_miner.so r2r_cuda_miner.cu
```

---

## ⚙️ Налаштування

Редагуйте `r2r_mining_config.json`:

```json
{
  "network": {
    "rpc_url": "http://localhost:8545"
  },
  "mining": {
    "mining_contract": "0x...", // Адреса контракту R2R
    "private_key": "0x..."       // Ваш приватний ключ
  }
}
```

### Важні параметри:

| Параметр | Опис | Значення |
|----------|------|---------|
| `rpc_url` | Blockchain RPC endpoint | http://localhost:8545 |
| `mining_contract` | Адреса R2RMiningPool контракту | 0x... |
| `private_key` | Ваш приватний ключ | 0x... |
| `default_difficulty` | Початкова складність | 100 |
| `auto_claim` | Автоматичне отримання винагород | true/false |
| `claim_interval_hours` | Інтервал отримання | 24 |

---

## 🚀 Запуск Майнингу

### Windows (просто)
```batch
start_mining.bat
```

### Windows (командний рядок)
```batch
python r2r_gpu_miner.py --config r2r_mining_config.json --duration 24 --claim
```

### Linux/Mac
```bash
python3 r2r_gpu_miner.py --config r2r_mining_config.json --duration 24 --claim
```

### Параметри:
- `--config` - Файл конфігурації (за замовчуванням: r2r_mining_config.json)
- `--duration` - Тривалість майнингу в годинах (за замовчуванням: 24)
- `--claim` - Автоматично отримати винагороди після майнингу

---

## 📈 Оптимізація Продуктивності

### NVIDIA RTX
```bash
# Включити наскрізну чисткою кешу
nvidia-smi -pm 1

# Встановити стійку енергію (RTX 3090)
nvidia-smi -pl 420

# Перевірити стан
nvidia-smi
```

### AMD RX
```bash
# Включити профіль 7
rocm-smi --setprofile 7

# Перевірити частоту GPU
rocm-smi --sclk
```

---

## 💰 Розрахунок Прибутку

### RTX 3090
- **Хешрейт:** ~100-150 MH/s (залежить від алгоритму)
- **Щоденна винагорода:** 0.5-2 R2R
- **Енергія:** 420W (10W/day при ціні $0.10/kWh)

### RX 6900 XT
- **Хешрейт:** ~80-120 MH/s
- **Щоденна винагорода:** 0.4-1.5 R2R
- **Енергія:** 405W (9.7W/day при ціні $0.10/kWh)

---

## 🔍 Моніторинг

```bash
# Переглядати логи в реальному часі
tail -f mining.log

# Статистика GPU (NVIDIA)
watch -n 1 nvidia-smi

# Статистика GPU (AMD)
watch -n 1 rocm-smi
```

---

## 🐛 Розв'язання Проблем

### Помилка: "No compatible GPU detected"
- Встановіть відповідні драйвери
- Перевірте, чи GPU розпізнана: `nvidia-smi` або `rocm-smi`

### Помилка: "Failed to connect to RPC"
- Перевірте RPC URL у конфігурації
- Переконайтеся, що blockchain node запущений

### Низька продуктивність
- Зменшіть інші програми
- Перевірте температуру GPU
- Оновіть драйвери

### Поділ на нуль при depositRewardPool
- Цілком виправлено в оновленому контракті (v1.1)
- Завжди перевіряйте наявність акцій перед розподілом

---

## 🔐 Безпека

⚠️ **НІКОЛИ не діліться приватним ключем!**

Способи забезпечити безпеку:
1. Використовуйте окремий гаманець для майнингу
2. Скоротіть доступ приватного ключа до r2r_mining_config.json
3. Розглядайте использование апаратних кошельків (Ledger, Trezor)

```bash
# Linux: Обмежити доступ
chmod 600 r2r_mining_config.json
```

---

## 📞 Підтримка

Помилки та пропозиції:
- GitHub Issues: [проект-репозиторій]
- Telegram: @RelaxCoinSupport
- Email: support@relaxcoin.io

---

## 📝 Ліцензія

MIT License - див. LICENSE

---

**Версія:** 1.0  
**Останнє оновлення:** 2026-09-01  
**Автор:** Relax Corporation
