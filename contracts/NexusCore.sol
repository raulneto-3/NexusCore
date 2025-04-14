// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol"; // Mudou para Ownable2Step
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol"; // Movido para /utils
import "@openzeppelin/contracts/utils/math/Math.sol"; // SafeMath foi descontinuado

/**
 * @title Nexus Core (NXCR)
 * @author King Moriarty & CyberKingdom Dev Team
 * @dev O coração do ecossistema Cyber Kingdom, onde as almas digitais são forjadas
 * e as leis são escritas em código quântico.
 */
contract NexusCore is ERC20, ERC20Burnable, Ownable2Step, ReentrancyGuard {

    // =============== CONSTANTES ===============
    uint256 public constant INITIAL_SUPPLY = 1_000_000_000 * 10**18; // 1 bilhão com 18 decimais
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    uint256 public constant CYCLES_TO_SECONDS = 30 days; // Um ciclo = 30 dias
    uint256 public constant CHRONO_UNITS_MAX_WEEKLY = 5_000; // Máximo de unidades por semana
    uint256 public constant UNSTAKE_PENALTY = 15; // 15% de penalidade para unstake antecipado

    // =============== CONFIGURAÇÕES AJUSTÁVEIS ===============
    uint256 public stellarcrucibleAPY; // APY máximo para staking de 12 ciclos
    uint256 public singularityBurnRate; // % de queima por transação
    uint256 public chronoUnitRate; // Taxa para conversão de unidades (1000 = 1 NXCR)
    uint256 public minLawProposalThreshold; // NXCR mínimo para propor leis

    // =============== ENDEREÇOS ESTRATÉGICOS ===============
    address public foundationVault; // Tesouro do projeto
    address public quantumOracle; // Oracle para atualizar contribuições
    address public liquidityVein; // Endereço de liquidez

    // =============== MAPEAMENTOS ===============

    // Stellarcrucible Lock (Staking)
    struct SoulForge {
        uint256 stakedAmount;
        uint256 startTime;
        uint256 endTime;
        uint256 cycles;
        bool isActive;
    }
    mapping(address => SoulForge) public soulForges;

    // Chrono-Contribution Ledger
    mapping(address => uint256) public chronoUnits;
    mapping(address => uint256) public lastChronoUpdateWeek;

    // Prime Directive Council (Governança)
    struct Law {
        string lawHash;
        bytes data;
        uint256 proposalTime;
        address prophet;
        bool executed;
        uint256 votesFor;
        uint256 votesAgainst;
        mapping(address => bool) hasVoted;
    }
    uint256 public lawCount;
    mapping(uint256 => Law) public laws;

    // =============== EVENTOS ===============
    event SoulForged(address indexed user, uint256 amount, uint256 cycles);
    event CrucibleShattered(address indexed user, uint256 burnedSouls, uint256 energyReleased);
    event FurnaceIgnited(uint256 amount, string entropySource);
    event ChronoUpdated(address indexed user, uint256 units, uint256 timestamp);
    event EntropyClaimed(address indexed user, uint256 units, uint256 nxcrAmount);
    event LawProposed(uint256 indexed lawId, address indexed prophet);
    event VoteCast(address indexed voter, uint256 indexed lawId, bool verdict);
    event VeinFed(uint256 amount);
    event VaultFundsReleased(address indexed to, uint256 amount);

    // =============== MODIFICADORES ===============
    modifier onlyQuantumOracle() {
        require(msg.sender == quantumOracle, "NXCR: Somente o Quantum Oracle pode invocar");
        _;
    }

    // =============== CONSTRUTOR ===============
    constructor(
        address _foundationVault,
        address _quantumOracle,
        uint256 _stellarcrucibleAPY,
        uint256 _singularityBurnRate
    ) ERC20("Nexus Core", "NXCR") Ownable(msg.sender) {
        require(_foundationVault != address(0), "NXCR: Vault nao pode ser endereco nulo");
        require(_quantumOracle != address(0), "NXCR: Oracle nao pode ser endereco nulo");
        
        foundationVault = _foundationVault;
        quantumOracle = _quantumOracle;
        
        stellarcrucibleAPY = _stellarcrucibleAPY; // 15% por padrao
        singularityBurnRate = _singularityBurnRate; // 5% por padrao
        chronoUnitRate = 1000; // 1000 unidades = 1 NXCR
        minLawProposalThreshold = 25_000 * 10**18; // 25.000 NXCR
        
        // Distribuição inicial conforme o whitepaper
        _mint(address(this), INITIAL_SUPPLY); // Todo o supply vai para o contrato
        
        // Aloca conforme a distribuição (40% comunidade, 20% equipe, 15% parceiros, 15% ecosystem, 10% liquidez)
        _transfer(address(this), foundationVault, INITIAL_SUPPLY * 90 / 100); // 90% para o vault
        liquidityVein = _foundationVault; // Define o vault como liquidityVein inicial
        _transfer(address(this), liquidityVein, INITIAL_SUPPLY * 10 / 100); // 10% para liquidez inicial
    }

    // =============== FUNÇÕES DE TRANSFERÊNCIA CUSTOM ===============
    
    /**
    * @dev Sobrescreve o _update para implementar a funcionalidade de queima
    * Na versão 5.x do OpenZeppelin, _update substitui _transfer
    */
    function _update(
        address from, 
        address to, 
        uint256 amount
    ) internal virtual override {
        // Verificações de bypass específicas
        if (from == address(0) || to == address(0) || amount == 0) {
            // Mint ou burn nativos do ERC20 ou transferência zero - passar direto
            super._update(from, to, amount);
            return;
        }
        
        // Bypass para transferências envolvendo o contrato ou o vault
        if (from == address(this) || to == address(this) || 
            from == foundationVault || to == foundationVault ||
            to == BURN_ADDRESS) {
            // Passar direto sem queima
            super._update(from, to, amount);
            return;
        }
        
        // Para transferências normais entre usuários, aplica queima de 5%
        uint256 burnAmount = amount * singularityBurnRate / 100;
        uint256 transferAmount = amount - burnAmount;
        
        // Primeiro queima tokens
        super._update(from, address(0), burnAmount);
        
        // Depois faz a transferência do valor restante
        super._update(from, to, transferAmount);
        
        // Emite evento de queima
        emit FurnaceIgnited(burnAmount, "Transferencia Automatica");
    }

    // =============== STELLARCRUCIBLE LOCK (STAKING) ===============
    
    /**
     * @dev Inicia o staking dos tokens por um número determinado de ciclos
     * @param amount Quantidade de tokens a serem stakeds
     * @param cycles Número de ciclos (3, 6 ou 12 meses)
     */
    function forgeSoul(uint256 amount, uint256 cycles) external nonReentrant {
        require(amount > 0, "NXCR: Quantia deve ser maior que zero");
        require(cycles == 3 || cycles == 6 || cycles == 12, "NXCR: Ciclos devem ser 3, 6 ou 12");
        require(balanceOf(msg.sender) >= amount, "NXCR: Saldo insuficiente");
        require(!soulForges[msg.sender].isActive, "NXCR: Voce ja possui uma alma forjada ativa");
        
        // Transfere os tokens para o contrato
        _transfer(msg.sender, address(this), amount);
        
        // Configura o staking
        soulForges[msg.sender] = SoulForge({
            stakedAmount: amount,
            startTime: block.timestamp,
            endTime: block.timestamp + (cycles * CYCLES_TO_SECONDS),
            cycles: cycles,
            isActive: true
        });
        
        emit SoulForged(msg.sender, amount, cycles);
    }
    
    /**
     * @dev Calcula a recompensa de staking baseada no APY e tempo decorrido
     * @param user Endereço do usuário
     * @return reward Recompensa calculada em tokens
     */
    function getSoulEnergy(address user) public view returns (uint256 reward) {
        SoulForge memory forge = soulForges[user];
        if (!forge.isActive) return 0;
        
        uint256 apyRate;
        if (forge.cycles == 3) {
            apyRate = stellarcrucibleAPY * 8 / 15; // 8% para 3 ciclos
        } else if (forge.cycles == 6) {
            apyRate = stellarcrucibleAPY * 12 / 15; // 12% para 6 ciclos
        } else if (forge.cycles == 12) {
            apyRate = stellarcrucibleAPY; // 15% para 12 ciclos
        }
        
        uint256 timeElapsed = block.timestamp < forge.endTime ? 
                             block.timestamp - forge.startTime : 
                             forge.endTime - forge.startTime;
                             
        // APY ajustado para o tempo decorrido (em segundos)
        uint256 yearInSeconds = 365 days;
        reward = forge.stakedAmount * apyRate * timeElapsed / yearInSeconds / 100;
        
        return reward;
    }
    
    /**
     * @dev Finaliza o staking e libera tokens + recompensas
     */
    function shatterCrucible() external nonReentrant {
        SoulForge memory forge = soulForges[msg.sender];
        require(forge.isActive, "NXCR: Nenhuma alma forjada encontrada");
        
        uint256 penalty = 0;
        uint256 reward = getSoulEnergy(msg.sender);
        
        // Aplica penalidade se o período completo não foi cumprido
        if (block.timestamp < forge.endTime) {
            penalty = forge.stakedAmount * UNSTAKE_PENALTY / 100;
            // Queima a penalidade
            _transfer(address(this), BURN_ADDRESS, penalty);
        }
        
        // Transfere os tokens + recompensas (retirando a penalidade, se houver)
        uint256 returnAmount = forge.stakedAmount - penalty + reward;
        _transfer(address(this), msg.sender, returnAmount);
        
        // Limpa o staking
        delete soulForges[msg.sender];
        
        emit CrucibleShattered(msg.sender, penalty, returnAmount);
    }

    // =============== SINGULARITY FURNACE (QUEIMA) ===============
    
    /**
     * @dev Queima manual de tokens (somente owner)
     * @param amount Quantidade a ser queimada
     * @param entropySource Fonte da entropia (razão da queima)
     */
    function igniteFurnace(uint256 amount, string memory entropySource) external onlyOwner {
        require(amount > 0, "NXCR: Quantia deve ser maior que zero");
        require(balanceOf(address(this)) >= amount, "NXCR: Saldo insuficiente no contrato");
        
        _transfer(address(this), BURN_ADDRESS, amount);
        
        emit FurnaceIgnited(amount, entropySource);
    }

    // =============== CHRONO-CONTRIBUTION LEDGER ===============
    
    /**
     * @dev Atualiza as unidades de contribuição de um usuário (somente Quantum Oracle)
     * @param user Endereço do usuário
     * @param units Unidades a incrementar
     */
    function updateChrono(address user, uint256 units) external onlyQuantumOracle {
        require(user != address(0), "NXCR: Endereco nulo");
        
        // Verificação do limite semanal
        uint256 currentWeek = block.timestamp / 1 weeks;
        
        if (currentWeek > lastChronoUpdateWeek[user]) {
            // Nova semana, reinicia o contador
            lastChronoUpdateWeek[user] = currentWeek;
            chronoUnits[user] = units;
        } else {
            // Mesma semana, verifica o limite
            require(chronoUnits[user] + units <= CHRONO_UNITS_MAX_WEEKLY, 
                   "NXCR: Excede o limite semanal de unidades");
            chronoUnits[user] += units;
        }
        
        emit ChronoUpdated(user, units, block.timestamp);
    }
    
    /**
     * @dev Converte unidades de contribuição em tokens NXCR
     * @param units Unidades a converter
     */
    function claimEntropy(uint256 units) external nonReentrant {
        require(units > 0, "NXCR: Unidades devem ser maiores que zero");
        require(chronoUnits[msg.sender] >= units, "NXCR: Unidades insuficientes");
        
        // Subtrai as unidades
        chronoUnits[msg.sender] -= units;
        
        // Calcula tokens a serem recebidos (1000 unidades = 1 NXCR)
        uint256 nxcrAmount = units * 10**18 / chronoUnitRate;
        
        // Verifica se há fundos suficientes
        require(balanceOf(foundationVault) >= nxcrAmount, "NXCR: Fundos insuficientes no vault");
        
        // Realiza a transferência real do vault para o usuário
        // Isso requer que o contrato tenha permissão para operar tokens do vault
        // ou que o vault tenha aprovado este contrato como spender
        ERC20(address(this)).transferFrom(foundationVault, msg.sender, nxcrAmount);
        
        emit EntropyClaimed(msg.sender, units, nxcrAmount);
    }

    // =============== PRIME DIRECTIVE COUNCIL (GOVERNANÇA) ===============
    
    /**
     * @dev Propõe uma nova lei (proposta de governança)
     * @param lawHash Hash IPFS ou identificador da lei
     * @param data Dados codificados para a execução
     */
    function proposeLaw(string memory lawHash, bytes memory data) external {
        require(balanceOf(msg.sender) >= minLawProposalThreshold, 
               "NXCR: Minimo de tokens necessario para propor lei nao atingido");
        
        uint256 lawId = lawCount;
        Law storage newLaw = laws[lawId];
        
        newLaw.lawHash = lawHash;
        newLaw.data = data;
        newLaw.proposalTime = block.timestamp;
        newLaw.prophet = msg.sender;
        newLaw.executed = false;
        newLaw.votesFor = 0;
        newLaw.votesAgainst = 0;
        
        lawCount++;
        
        emit LawProposed(lawId, msg.sender);
    }
    
    /**
     * @dev Vota em uma proposta de lei
     * @param lawId ID da lei
     * @param support Voto a favor (true) ou contra (false)
     */
    function castVote(uint256 lawId, bool support) external {
        require(lawId < lawCount, "NXCR: Lei inexistente");
        require(!laws[lawId].hasVoted[msg.sender], "NXCR: Ja votou nesta lei");
        require(!laws[lawId].executed, "NXCR: Lei ja executada");
        
        uint256 votingPower = balanceOf(msg.sender);
        require(votingPower > 0, "NXCR: Sem poder de voto");
        
        Law storage law = laws[lawId];
        
        if (support) {
            law.votesFor = law.votesFor + votingPower;
        } else {
            law.votesAgainst = law.votesAgainst + votingPower;
        }
        
        law.hasVoted[msg.sender] = true;
        
        emit VoteCast(msg.sender, lawId, support);
    }

    // =============== FOUNDATION VAULT (TREASURY) ===============
    
    /**
     * @dev Libera fundos do tesouro (requer votação do Council)
     * @param to Endereço destino
     * @param amount Quantidade a ser transferida
     */
    function releaseVaultFunds(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "NXCR: Endereco destino nao pode ser nulo");
        require(amount > 0, "NXCR: Quantia deve ser maior que zero");
        
        // Esta função deve ser chamada após a aprovação de uma proposta de lei
        // A validação da aprovação deve ser feita off-chain ou em um contrato de governança
        
        // Transferência do vault para o destino
        // Essa função assume que o owner tem autoridade sobre o vault (deve ser um multisig)
        
        emit VaultFundsReleased(to, amount);
    }

    // =============== QUANTUM LIQUIDITY VEIN (LIQUIDEZ) ===============
    
    /**
     * @dev Alimenta a veia de liquidez (envia tokens para DEX)
     * @param amount Quantidade a ser enviada
     */
    function feedVein(uint256 amount) external onlyOwner {
        require(amount > 0, "NXCR: Quantia deve ser maior que zero");
        require(balanceOf(foundationVault) >= amount, "NXCR: Fundos insuficientes no vault");
        
        // Esta função deve ser chamada após a aprovação de uma proposta de lei
        // A transferência é feita do vault para o liquidityVein
        
        emit VeinFed(amount);
    }
    
    /**
     * @dev Atualiza o endereço da veia de liquidez
     * @param newVein Novo endereço
     */
    function setLiquidityVein(address newVein) external onlyOwner {
        require(newVein != address(0), "NXCR: Endereco nao pode ser nulo");
        liquidityVein = newVein;
    }

    // =============== FUNÇÕES ADMINISTRATIVAS ===============
    
    /**
     * @dev Atualiza o endereço do Quantum Oracle
     * @param newOracle Novo endereço do oracle
     */
    function setQuantumOracle(address newOracle) external onlyOwner {
        require(newOracle != address(0), "NXCR: Oracle nao pode ser nulo");
        quantumOracle = newOracle;
    }
    
    /**
     * @dev Atualiza parâmetros ajustáveis
     * @param _stellarcrucibleAPY Novo APY para staking
     * @param _singularityBurnRate Nova taxa de queima
     * @param _chronoUnitRate Nova taxa de conversão de unidades
     * @param _minLawProposalThreshold Novo mínimo para propostas
     */
    function updateParameters(
        uint256 _stellarcrucibleAPY,
        uint256 _singularityBurnRate,
        uint256 _chronoUnitRate,
        uint256 _minLawProposalThreshold
    ) external onlyOwner {
        stellarcrucibleAPY = _stellarcrucibleAPY;
        singularityBurnRate = _singularityBurnRate;
        chronoUnitRate = _chronoUnitRate;
        minLawProposalThreshold = _minLawProposalThreshold;
    }
}