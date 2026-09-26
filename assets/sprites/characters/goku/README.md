# Goku sprite setup

Os sprites usados nesta pasta são mantidos localmente e não são versionados no repositório público.

Para o primeiro conjunto de animações, coloque o arquivo processado em:

```text
assets/sprites/characters/goku/processed/goku_buus_fury_base.png
```

Formato esperado:

- 192 x 128 px;
- frames de 32 x 32 px;
- 6 colunas x 4 linhas;
- linhas: down, left, right, up;
- coluna 0: idle;
- colunas 2, 3, 4 e 5: walk.

O `PlayerAnimationController` detecta esse arquivo automaticamente e cria em tempo de execução:

```text
idle_down
idle_left
idle_right
idle_up
walk_down
walk_left
walk_right
walk_up
```

Se o arquivo não existir, o Player continua usando o placeholder de desenvolvimento.
