# Локальное тестирование перед публикацией

Перед тем как пушить изменения, протестируйте chart локально.

## 1. Проверка синтаксиса

```bash
# Lint chart
helm lint .

# Должен вывести: "1 chart(s) linted, 0 chart(s) failed"
```

## 2. Проверка шаблонов

```bash
# Проверить что шаблоны генерируются правильно
helm template healenium . > /tmp/healenium-manifests.yaml

# Просмотреть сгенерированные манифесты
cat /tmp/healenium-manifests.yaml
```

## 3. Dry-run установка

```bash
# Симуляция установки без реального применения
helm install healenium . --dry-run --debug
```

## 4. Проверка зависимостей

```bash
# Проверить requirements.yaml
cat requirements.yaml

# Если есть зависимости, обновить их
helm dependency update
```

## 5. Проверка значений

```bash
# Показать значения по умолчанию
helm show values .

# Проверить специфические значения
cat values.yaml
```

## 6. Локальная упаковка chart

```bash
# Упаковать chart
helm package .

# Должен создать файл healenium-0.1.0.tgz

# Проверить содержимое пакета
tar -tzf healenium-0.1.0.tgz

# Удалить временный файл
rm healenium-0.1.0.tgz
```

## 7. Проверка метаданных

```bash
# Показать информацию о chart
helm show chart .

# Вывод должен содержать:
# - name: healenium
# - version: 0.1.0
# - description: ...
```

## 8. Тестовая установка в minikube (опционально)

Если есть локальный minikube кластер:

```bash
# Запустить minikube
minikube start

# Установить PostgreSQL
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install db bitnami/postgresql \
  --set global.postgresql.auth.postgresPassword=admin \
  --set global.postgresql.auth.username=healenium_user \
  --set global.postgresql.auth.password=YDk2nmNs4s9aCP6K \
  --set global.postgresql.auth.database=healenium

# Установить Healenium
helm install healenium .

# Проверить статус
kubectl get pods
helm list

# Удалить после тестирования
helm uninstall healenium
helm uninstall db
```

## 9. Проверка workflow файла

```bash
# Проверить синтаксис YAML
cat .github/workflows/release.yml

# Можно использовать yamllint если установлен
# yamllint .github/workflows/release.yml
```

## Checklist перед push

- [ ] `helm lint .` выполняется без ошибок
- [ ] `helm template healenium .` генерирует корректные манифесты
- [ ] `helm install --dry-run` завершается успешно
- [ ] Версия в `Chart.yaml` обновлена (если требуется)
- [ ] `README.md` актуален
- [ ] Все новые файлы добавлены в git
- [ ] Commit message информативен

## После успешных тестов

```bash
# Добавить все файлы
git add .github/ *.md .gitignore artifacthub-repo.yml README.md

# Коммит
git commit -m "feat: add public Helm repository support

Resolves #8"

# Push
git push origin master
```

## Мониторинг после push

1. Следить за GitHub Actions: https://github.com/healenium/kubernetes/actions
2. Проверить создание Release через 2-3 минуты
3. Проверить появление ветки `gh-pages`
4. Настроить GitHub Pages (если еще не настроено)
5. Протестировать публичный репозиторий (через 5-10 минут):
   ```bash
   helm repo add healenium https://healenium.github.io/kubernetes
   helm repo update
   helm search repo healenium
   ```

