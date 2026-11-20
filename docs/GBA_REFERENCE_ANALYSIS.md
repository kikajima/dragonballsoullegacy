# Análise das referências GBA

## Ampliação de 01/11/2026

Estudo de sistemas, diferenças entre referências, diagnóstico do DBSL e propostas priorizadas: [HU2_LOG_IMPLEMENTATION_STUDY.md](HU2_LOG_IMPLEMENTATION_STUDY.md). Análise estática específica de HU2: [HU2_CODE_STUDY.md](HU2_CODE_STUDY.md).

O REA 6.5.0 foi executado novamente nas três ROMs: todas continuam recusadas pelo adaptador raw ARM no Windows. A importação de código HU2 também retornou `unsupported_host`. Saídas JSON preservadas em `references/roms/analysis/*2026-11-01.json`. A análise complementar usa código-fonte, manuais e imagens; não atribui a esses comandos uma descompilação que não ocorreu. As 270 imagens locais GBA passaram na verificação de leitura/integridade.

## Triagem de 16/10/2026

Arquivos lidos em `references/roms`, sem modificar as ROMs. Inventário reproduzível: `python tools/inspect_gba_references.py`. Hashes completos, versão, cabeçalhos e pistas textuais ficam em `references/roms/inventory.json`, ignorado pelo Git.

| Arquivo | Título interno | Código | Revisão | Tamanho |
| --- | --- | --- | --- | --- |
| Buu's Fury (USA) | DBZBUUSFURY | BG3E | 0 | 8 MiB |
| The Legacy of Goku (USA) | DBZ LGCYGOKU | ALGE | 0 | 8 MiB |
| The Legacy of Goku II (USA) | DBZLGCYGOKU2 | ALFE | 0 | 8 MiB |

Todos passaram na verificação do byte fixo e checksum do cabeçalho. Isso não certifica a integridade de todo o conteúdo nem confirma equivalência com uma versão comercial específica.

## Resultado real do REA 6.5.0

Tentativa no Legacy of Goku II:

```powershell
$romPath = (Get-ChildItem references/roms -Filter '*Goku II*').FullName
rea analyze $romPath --target-format raw-binary --architecture arm --entry-point 0x08000000 --provider ghidra
```

Resultado: `capability_unavailable / unsupported_provider`. O adaptador informa `target_format_unsupported`: no Windows, esta versão admite PE nativo e raw 6502, não raw ARM. Ghidra também não está configurado, mas configurá-lo sozinho não elimina a restrição do adaptador. Hopper não suporta este host e o adaptador IDA não admite raw binaries. O endereço foi fornecido como hipótese de mapeamento de cartucho; o REA não chegou a desassemblar ou validar código.

Portanto, nenhuma mecânica GBA foi confirmada pelo REA nesta etapa. A opção ARM mostrada na ajuda não garante suporte em todos os provedores/hosts.

## Pistas estáticas confirmadas

Em Legacy of Goku II foram encontrados textos ASCII de técnicas, incluindo Kamehameha em offset de arquivo `0xE37AC`, Special Beam Cannon em `0xE3780`, Scatter Shot em `0xE3A0E` e Spirit Bomb em `0xE3A34`. Esses offsets apontam para texto, não para funções de ataque. A busca simples não encontrou as palavras consultadas em Buu's Fury; isso não demonstra ausência das técnicas, pois o texto pode usar outra codificação ou compressão.

## Plano de investigação de comportamento

Na triagem inicial não foi encontrado mGBA. Posteriormente, o VBA-M fornecido pelo usuário permitiu executar as três ROMs; resultados abaixo.

O mGBA oferece execução por frames e acesso à memória por scripting: https://mgba.io/docs/scripting.html . A identificação do cabeçalho é compatível com o layout usado por implementações GBA, como https://github.com/PeterLemon/GBA/blob/master/LIB/GBA_HEADER.ASM .

Para cada jogo, coletar evidências independentes:

1. Kamehameha: início, carga, soltura, duração, gasto de Ki, contato com parede, alvo vivo e alvo derrotado; repetir com dois inimigos alinhados.
2. Técnicas: alcance, cadência, área, atordoamento, cancelamento e poses nas quatro direções.
3. Movimento: pixels por frame, diagonais, colisões, voo e transições.
4. Progressão: atributos, experiência, equipamento e aquisição de habilidades.
5. Ilha: tiles, paletas, bordas, animações de água, disposição e colisões.

Saves `.sav` próximos de combates e com habilidades liberadas permitem observar esses cenários sem depender de completar a campanha. Registrar versão do emulador e hash da ROM em cada captura. Vídeos e medidas precisam ser relacionados ao jogo correto; HU2, Legacy of Goku, Legacy of Goku II e Buu's Fury não são referências intercambiáveis.

## Saves recebidos

- `dragon-ball-z-the-legacy-of-goku.22862.gsv`: 1.584 bytes, assinatura `ADVSAVEG`, título correspondente à ROM, tipo 3 (EEPROM 512 bytes) e rodapé `78563412`. Cópia convertida em `references/roms/prepared/Dragon Ball Z - The Legacy of Goku (USA).sav`; payload a partir de `0x430`, inversão de cada bloco de oito bytes conforme o importador mGBA. Transformação reversível conferida, original preservado. O checksum GSV não foi validado: seu algoritmo também é tratado como desconhecido no importador consultado. Descrição interna: “Get vengeance for Krillin!”. Não confirma habilidades liberadas.
- `dragon-ball-z-the-legacy-of-goku-ii.16615.sps`: 63.297 bytes, assinatura gzip. Descompacta para 739.838 bytes, começa com inteiro 8 e identificação `DBZLGCYGOKU2ALFE`. Indícios de save state de emulador, não de container SharkPort; conversão pendente de identificação do layout.
- `dragon-ball-z-buus-fury.20540.sps`: 8.192 bytes, sem cabeçalho SharkPort. Candidato a EEPROM bruto de 8 KiB; associação ao jogo deriva do nome do arquivo, não de identificação interna. Ordem dos bytes e validade do progresso ainda não confirmadas.

Referência para a conversão GSV: https://github.com/mgba-emu/mgba/blob/master/src/gba/sharkport.c . As descrições acima registram a triagem dos arquivos; a validação posterior está abaixo. Não basta renomear todos para `.sav`.

## Validação no VBA-M 2.1.11 — 17/10/2026

Os três saves carregaram em execução real, usando as ROMs identificadas no inventário. Originais mantidos separados das cópias de trabalho em `references/roms/analysis/vba-session`.

| Jogo | Procedimento validado | Resultado observado |
| --- | --- | --- |
| Legacy of Goku | GSV convertido para EEPROM de 512 bytes; Continue → Slot 1 | Goku transformado em uma área rochosa com lava |
| Legacy of Goku II | Arquivo `.sps` carregado como estado legado pelo menu Load state → From File | Hercule nível 50 em área urbana; bateria exportada pelo VBA para `.sav` de 8 KiB |
| Buu's Fury | `.sps` de 8 KiB usado como bateria na cópia de trabalho | Slot 1: Kid Buu Saga / West City; Goku nível 200; Kamehameha e Instant Transmission nível 3 |

Em Buu's Fury, a descrição do Kamehameha instrui: “Hold the B Button to emit a long beam of energy.” Isso confirma o comando indicado pelo jogo, mas **não comprova continuidade após matar um inimigo**. As tentativas de execução nesta sessão ainda não produziram uma captura inequívoca do feixe; não foram usadas para medir duração, consumo ou dano. Saves obtidos online, especialmente com atributos elevados, também não servem para inferir progressão normal.

Evidências locais (ignoradas pelo Git), em `references/roms/analysis/vba-session/`:

- `log1-verified.png`: Slot 1 carregado em gameplay.
- `log2-menu.png`: status de Hercule nível 50.
- `buu-slots.png`: capítulo e local do save.
- `buu-status.png`: status de Goku.
- `buu-skills.png` e `buu-kame-description.png`: catálogo e instrução de sustentação.

### Abrir as referências localmente

Feche a instância anterior do VBA antes de abrir outra. Na raiz do projeto:

```powershell
powershell -ExecutionPolicy Bypass -File tools/start_gba_reference.ps1 -Game buu -FromBattery
# Outros jogos: -Game log1 ou -Game log2
```

O script usa o emulador e as ROMs locais, copia a bateria preparada apenas se a cópia de trabalho não existir e mantém estados/capturas no diretório de sessão. Sem `-FromBattery`, solicita carregar o estado mais recente. Não distribui ROMs, saves ou executáveis pelo Git.

Controles configurados: WASD = direções; L = botão A; K = botão B; I/O = ombros L/R; Enter = Start; Backspace = Select. O menu Emulation → Pause permite retomar uma sessão pausada. Para voltar ao progresso preparado, preserve sua bateria de trabalho antes de substituí-la pela cópia em `references/roms/prepared`.

Ainda pendentes: feixe sustentado em combate, morte do alvo e segundo alvo alinhado, medidas por frame, colisões e comparação entre jogos. Nenhuma destas observações deve ser atribuída ao REA, cujo adaptador recusou raw ARM.

## Regra atual do projeto

A continuidade do Kamehameha após derrotar o alvo foi implementada por solicitação do usuário e validada no Godot. Ainda não deve ser apresentada como uma reprodução comprovada de qualquer uma destas ROMs. A compra universal de habilidades é uma regra do MMORPG, independente de restrições dos jogos de referência.
