# TaskFlow — Flutter + SQLite + Drift

Локальное офлайн-приложение для управления проектами и задачами.

## Запуск

```bash
flutter pub get
 dart run build_runner build --delete-conflicting-outputs
flutter run
```

## Тесты

```bash
flutter test
```

База данных SQLite хранится локально на устройстве. Для генерации Drift необходимо выполнить build_runner после получения зависимостей.
