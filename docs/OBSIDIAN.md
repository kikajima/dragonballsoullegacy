# Visualizar a biblioteca no Obsidian

Use um cofre só para documentação e curadoria. O projeto Godot permanece no diretório atual; não é necessário duplicá-lo nem copiar ROMs para o Obsidian.

1. No Obsidian, escolha **Open folder as vault / Abrir pasta como cofre**.
2. Selecione `E:\jogos feitos com ia\DBSL\dragon-ball-soul-legacy-git\generated\sprites\catalog\obsidian`.
3. Abra **Início**, depois **Fontes**, para navegar pelas 344 fichas.
4. Cada ficha tem links para a folha original e para o personagem/folha no catálogo visual. Se o aplicativo não abrir o link local, abra `generated/sprites/catalog/index.html` no navegador e filtre pelo nome.
5. Escreva suas anotações em **Curadoria.md**. As fichas e índices são gerados novamente; esse arquivo de notas é preservado.

Em **Início → Personagens GBA**, há links para os recortes individuais de 21 folhas coletivas e para o índice visual de personagens. Nomes genéricos indicam identidade ainda pendente de curadoria; a separação não confirma as animações.

O Obsidian organiza as relações entre notas. A seleção dos recortes, animações e decisões exportáveis fica no catálogo HTML. Não é necessário instalar plugins.

Para atualizar ambos:

```powershell
python tools/map_sprite_library.py --refresh-reviews
```

Se adicionar ou remover fontes, execute sem `--refresh-reviews` para refazer o inventário. Os links apontam para caminhos locais: após mover as fontes ou o projeto, refaça a geração. O cofre está em `generated/sprites/`, ignorado pelo Git; mantenha uma cópia de `Curadoria.md` e do JSON exportado antes de apagar essa pasta ou migrar de computador.

Referência: [abrir uma pasta existente como cofre](https://help.obsidian.md/vault).
