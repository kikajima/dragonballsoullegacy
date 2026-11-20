# Testar a ilha e as habilidades

Reaproveitamento dos sprites ambientais: veja [MAP_ASSETS.md](MAP_ASSETS.md) para fontes, recortes, colisões e reprodução local dos móveis GBA.

## Sprites de habilidades — 31/10/2026

Big Bang Attack usa `BigBangAttackHead/Hit` e Burning Attack usa `BurningAttHead/Hit` do HU2, com os quadros direcionais de voo e impacto. O impacto mostra os dois quadros dentro da duração existente de 0,16 s, sem alterar dano/alcance. Scatter Shot usa o estágio final da esfera GBA durante o voo: os recortes de crescimento não são mais repetidos como animação. Spirit Bomb mantém o comportamento anterior.

`tools/test_special_projectile_art.gd` verifica oito casos de direção, pixels, dano, stun, colisão e expiração, e gera `audit-skill-art-gallery.png` quando executado com renderização. `tools/test_special_hits.gd` verifica dano/efeito das 15 técnicas ofensivas e passou sem falhas. As duas transformações não são alteradas por esta revisão.

## Revisão de jogabilidade e apresentação — 30/10/2026

- Mantida a HUD em 50%, com a técnica abaixo de vida/Ki. Carga usa ciano, recarga usa cobre e bloqueio usa vermelho suave, com ícone atenuado. Um uso válido limpa imediatamente o aviso da tentativa anterior. O Kamehameha indica segurar para canalizar; técnicas de projétil indicam soltar.
- Notificações ficam na parte inferior, com largura ajustada ao conteúdo e quebra de linha. Alvo e painel de treino acompanham o redimensionamento da janela.
- Grama da ilha com contraste reduzido sem desfocar pixels. Píer com tábuas, pregos e bordas; placa com detalhes de madeira e escrita. Colisões preservadas.
- Dash não consome Ki nem inicia durante atordoamento, morte, retorno ao checkpoint, ataques ou treino na esteira. Uma interrupção restaura a velocidade.
- Ao retornar após derrota, status, combo e recuperação do golpe anterior são limpos. A restauração de vida inicia uma proteção de 1 segundo, incluindo a transição de entrada.

Validação local: `tools/test_hud_layout.gd` (17 técnicas, carga, recarga, mensagens e sobreposições), `tools/test_player_recovery.gd` (dash e morte/retorno reais) e `tools/audit_gameplay.gd` (combate, cinco mapas, colisões, save/load descartável). Todos passaram. A auditoria com renderização gera `audit-kame_island.png` para comparar a apresentação.

Revisão da HUD e pixels: renderização `canvas_items` mantém as fontes na resolução da janela, sem ampliar um framebuffer de baixa resolução. O painel de habilidades tem margens maiores, nome separado do atalho R e notificações deslocadas para não se sobrepor. Ícones são enquadrados pela área visível da imagem. A grama recebeu redução de saturação e contraste, sem filtro de desfoque.

As alterações estão no projeto local. Abra `project.godot` no Godot 4.7 e pressione **F5**. Não é necessário deploy para jogar localmente.

No PowerShell, na pasta do projeto:

```powershell
& "$env:USERPROFILE/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe" --path .
```

- R troca a habilidade; O usa; segurar/soltar O controla cargas.
- Todas as 17 habilidades estão liberadas para testes, independentemente do personagem.
- Confira a areia clara na praia, a seleção persistente e os avisos de Ki/recarga.
- Loja e compra são etapas futuras: as habilidades pertencem ao personagem por aquisição, sem exclusividade por raça/personagem. O save já guarda as habilidades adquiridas.

Testes reproduzíveis:

```powershell
$godotExe = "$env:USERPROFILE/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe"
& $godotExe --headless --path . --log-file ./audit-skills.log --script res://tools/audit_gameplay.gd
& $godotExe --headless --path . --log-file ./audit-catalog.log --script res://tools/test_special_catalog.gd
& $godotExe --headless --path . --log-file ./audit-hits.log --script res://tools/test_special_hits.gd
& $godotExe --path . --log-file ./audit-catalog-visual.log --script res://tools/test_special_catalog.gd -- --visual
```

O último comando gera capturas `audit-skill-*.png` para inspeção visual. Os testes não salvam sobre o progresso do jogador; a auditoria de gameplay usa um save descartável.

## Publicar o código no GitHub

Esta pasta também contém alterações locais anteriores. Confira `git diff` e selecione os arquivos desejados antes do commit. Para publicar a areia, o HUD e as correções deste trabalho em uma branch:

```powershell
git switch -c fix/kame-sand-skills
git add assets/tiles/kame_island scenes/world/kame_island.gd combat/special/special_attack_component.gd data/abilities/special/super_namek.tres ui/abilities/special_status_hud.gd ui/abilities/special_status_hud.tscn docs/SPECIAL_ATTACKS.md docs/TESTAR_AREIA_E_SKILLS.md tools/test_special_catalog.gd tools/test_special_hits.gd tools/preview_kame_sand.gd
git diff --cached
git commit -m "Apply Kame Island sand and fix shared skill casting and HUD"
git push -u origin fix/kame-sand-skills
```

Os arquivos já modificados antes deste trabalho podem incluir outras correções no mesmo diff. Revise a branch antes de integrar em `develop`. Capturas e logs de auditoria não precisam ser publicados. Publicar o código não hospeda um servidor MMORPG; para distribuir um executável, configure um preset em **Projeto > Exportar** e instale os templates da mesma versão do Godot. Um clone limpo também precisa dos assets locais ignorados pelo Git, indicados em `.gitignore`.
## Correções verificadas — 31/10/2026

- Carregar um save limpa o ataque anterior, projéteis, atordoamento, empurrão, combo, recargas e dash; encerra a sessão de esteira sem prender o jogador na posição antiga. Os recursos são restaurados depois dessa limpeza.
- Salvar/carregar durante o retorno após derrota é recusado, preservando o save saudável. Carregar durante uma viagem também é recusado; o menu apresenta o motivo.
- Portais recusam viagens simultâneas e permitem tentar novamente após uma falha de destino. A verificação adicional de 01/11 reproduziu quatro falhas na combinação morte/viagem: o retorno agora espera a viagem terminar e novas viagens são recusadas durante o retorno.
- Diálogos longos são paginados dentro da caixa. Substituir um diálogo aberto preserva o estado de pausa original, evitando deixar o jogo pausado ao fechar.
- A pose de preparação da Spirit Bomb carrega a textura importada do Godot, eliminando o acesso direto ao PNG de origem em runtime.

Regressões reproduzidas antes das correções: 10 falhas no carregamento/derrota, 6 nas transições e 25 nas verificações de diálogo. Os testes correspondentes passaram após as mudanças, incluindo carregamento durante dash e treino. Saves de teste são descartáveis; os diálogos usam uma cena isolada.

```powershell
$godotExe = "$env:USERPROFILE/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe"
& $godotExe --headless --path . --script res://tools/test_save_runtime.gd
& $godotExe --headless --path . --script res://tools/test_world_transitions.gd
& $godotExe --headless --path . --script res://tools/test_dialogue_pages.gd
& $godotExe --headless --path . --script res://tools/test_player_recovery.gd
& $godotExe --path . --script res://tools/audit_gameplay.gd
```

O teste de transições provoca intencionalmente um aviso de destino inexistente para verificar a recuperação do portal. A auditoria com renderização passou nos cinco mapas, colisões, combate e save/load; o Kamehameha continuou após derrotar o alvo. Isso cobre os cenários testados, sem substituir testes prolongados de exploração ou do executável exportado.

# Atualização visual — 17/10/2026

- Layout lógico de 480 × 270 com ampliação inteira. A revisão posterior voltou a `canvas_items` para renderizar fontes na resolução da janela e evitar letras serrilhadas.
- Sombras de contato em degraus sob jogador, inimigos e NPCs.
- Rochas com paleta quente, contorno escuro, sombra projetada e borda iluminada; relevo também na construção e no canteiro de West City.
- Painel de habilidades com fundo azul escuro, moldura clara e nome dourado, preservando espaço para carga e recarga.

Para visualizar, abra `project.godot` e pressione F5. Compare a ilha, Rocky Wastes e West City, caminhe perto dos objetos e redimensione a janela. As mudanças são inspiradas na apresentação GBA; não representam uma reprodução integral dos jogos originais.

Validação: `tools/audit_gameplay.gd` executado com renderização, conferência de capturas e aprovação dos cinco mapas, colisões, interface, save/load e continuidade do feixe após derrotar um alvo. O ambiente apresentou avisos de acesso ao log do usuário e certificados, sem falha nas verificações de gameplay.
