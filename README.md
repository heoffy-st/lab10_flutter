# TaskFlow — Flutter + SQLite + Drift

Офлайн-приложение для управления проектами, участниками и задачами.

## Возможности

- Пользователи: создание, изменение, список, просмотр назначенных задач и безопасное удаление.
- Проекты: создание, статусы, участники и роли Owner / Admin / Member.
- Задачи: CRUD, исполнители, приоритеты, статусы, дедлайны, поиск и фильтры.
- История статусов, Undo, комментарии и вложения (в БД хранится путь к файлу).
- Dashboard: сводка, приоритеты, исполнители и прогресс проектов.
- Корзина с Soft Delete, восстановлением и окончательным удалением.
- SQLite через Drift, внешние ключи, уникальность email, индексы, транзакции и миграция v1 → v2.
- Реактивные списки через Drift watch(); запросы вынесены в Repository.

## Запуск

Требуется установленный Flutter SDK.

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

Drift генерирует `lib/database/app_database.g.dart` командой build_runner. Этот файл не редактируется вручную.

## Тесты

```bash
flutter test
```

Набор тестов расположен в `test/taskflow_repository_test.dart`.

## Структура

- `lib/database` — Drift schema, SQLite connection и migration.
- `lib/data` — Repository и бизнес-правила.
- `lib/presentation` — экраны и навигация.
- `test` — автоматические тесты.
