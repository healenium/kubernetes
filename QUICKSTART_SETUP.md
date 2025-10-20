# Быстрый старт: Активация публичного Helm репозитория

## Что было сделано

Для вашего проекта Healenium настроена автоматическая публикация Helm chart в публичный репозиторий.

### Созданные файлы:

1. **`.github/workflows/release.yml`** - GitHub Actions workflow для автоматической публикации
2. **`.github/cr.yaml`** - Конфигурация Chart Releaser
3. **`HELM_REPOSITORY_SETUP.md`** - Подробная документация по настройке и поддержке
4. **`.gitignore`** - Игнорирование временных файлов
5. **`artifacthub-repo.yml`** - Конфигурация для Artifact Hub (опционально)
6. **`README.md`** - Обновлен с инструкциями по использованию публичного репозитория

## Что нужно сделать (3 шага)

### Шаг 1: Включить GitHub Pages

1. Перейдите в настройки репозитория:
   ```
   https://github.com/healenium/kubernetes/settings/pages
   ```

2. В разделе "Source" выберите:
   - **Branch**: `gh-pages` (эта ветка будет создана автоматически после первого запуска workflow)
   - **Folder**: `/ (root)`

3. Нажмите **Save**

> **Примечание**: Если ветка `gh-pages` еще не существует, вернитесь к этому шагу после первого релиза.

### Шаг 2: Настроить права GitHub Actions

1. Перейдите в настройки Actions:
   ```
   https://github.com/healenium/kubernetes/settings/actions
   ```

2. В разделе "Workflow permissions":
   - Выберите **"Read and write permissions"**
   - Включите **"Allow GitHub Actions to create and approve pull requests"**

3. Нажмите **Save**

### Шаг 3: Запустить первый релиз

1. Закоммитьте и запушьте созданные файлы:
   ```bash
   git add .github/ HELM_REPOSITORY_SETUP.md QUICKSTART_SETUP.md .gitignore artifacthub-repo.yml README.md
   git commit -m "feat: add public Helm repository support"
   git push origin master
   ```

2. Убедитесь, что workflow запустился:
   ```
   https://github.com/healenium/kubernetes/actions
   ```

3. После успешного выполнения workflow:
   - Проверьте, что создан Release: `https://github.com/healenium/kubernetes/releases`
   - Проверьте, что создана ветка `gh-pages`
   - Вернитесь к **Шагу 1** и активируйте GitHub Pages (если не сделали ранее)

4. Проверьте, что репозиторий доступен:
   ```bash
   curl https://healenium.github.io/kubernetes/index.yaml
   ```

## Как пользователи будут устанавливать

После активации пользователи смогут установить ваш chart так:

```bash
# Добавить репозиторий
helm repo add healenium https://healenium.github.io/kubernetes
helm repo update

# Установить Healenium
helm install healenium healenium/healenium
```

**Вместо текущего способа:**
```bash
git clone https://github.com/healenium/kubernetes.git
cd kubernetes
helm install healenium .
```

## Как делать новые релизы

Просто обновите версию в `Chart.yaml`:

```yaml
version: 0.1.1  # увеличьте версию
```

И закоммитьте:
```bash
git add Chart.yaml
git commit -m "chore: bump version to 0.1.1"
git push origin master
```

Новая версия автоматически опубликуется! 🚀

## Проверка работы

После первого релиза проверьте:

```bash
# Добавить репозиторий
helm repo add healenium https://healenium.github.io/kubernetes
helm repo update

# Найти chart
helm search repo healenium

# Посмотреть информацию
helm show chart healenium/healenium
helm show values healenium/healenium

# Тестовая установка (dry-run)
helm install test healenium/healenium --dry-run
```

## Нужна помощь?

Смотрите подробную документацию в **`HELM_REPOSITORY_SETUP.md`**

## Ответ пользователю

После настройки ответьте на issue #8:

```markdown
Hi @AndreiLepkovTR!

Thank you for the feature request! 🎉

We've implemented a public Helm repository. You can now install Healenium without cloning the repo:

**bash
helm repo add healenium https://healenium.github.io/kubernetes
helm repo update
helm install healenium healenium/healenium
**

The repository is now available at: https://healenium.github.io/kubernetes

Updated installation instructions are in our README: https://github.com/healenium/kubernetes#quick-start

Feel free to try it out and let us know if you have any questions!
```

