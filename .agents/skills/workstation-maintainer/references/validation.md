# Validation matrix

## All changes

```bash
./script/test
```

## Package profiles

```bash
./script/render-brewfile --output /tmp/workstation.Brewfile
./tests/render-brewfile.sh
```

## Shell scripts

```bash
bash -n path/to/script
shellcheck -x path/to/script
```

## Project-local MLX

```bash
uv add mlx
# On the target Mac, run the project's MLX-specific verification.
```

## Chezmoi

```bash
chezmoi diff
```
