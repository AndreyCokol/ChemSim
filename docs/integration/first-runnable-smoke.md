# ChemSim — первая исполняемая интеграция (технический smoke v0.1)

**Область:** отдельная ветка `integration/first-kinetics-smoke`, PR #17 и Issue #16. Не сливать с исходными ветками A2/A4/A5 без независимого ревью. OpenSpec v0.1 разрешён владельцем. **Это инженерный тест, а не научная химическая симуляция для произвольных веществ.**

## Что действительно работает

- Godot 4.3 (A5) содержит пользовательский интерфейс, сохранение черновиков и визуальное поле.
- A2 — реальный GDScript-парсер проверяет формулу, фазу, стехиометрию и атомный/зарядовый баланс учебной реакции `N2O4(g) -> 2NO2(g)`.
- `scripts/a5_smoke_contract.gd` формирует отдельный v0.1-запрос с явной `data_quality=hypothetical`, стабильными ссылками участников, количеством вещества в молях, объёмом в м³ и температурой в K. В тесте кинетический порядок **вводится отдельно**, константа `k=0.1 s⁻¹` намеренно **синтетическая**; из термодинамической K ничего не выводится.
- A4 — реальный .NET 10 CLI вычисляет необратимую кинетику закрытой изотермической системы. Выходной статус, ID запроса, количество точек, временная шкала, конечность чисел и атомный баланс проходят проверку A5 до визуализации.
- `scripts/a5_solver_process.gd` запускает CLI неблокирующим внешним процессом и принимает ответ через случайно названные `user://solver-jobs/` JSON файлы; запрос/ответ ограничены по размеру, время ожидания — 30 с. Нет обязательного сетевого сервера.
- A5 показывает фактическую концентрацию NO₂ и постоянную T на графиках, а также воспроизводит только **полученные от A4** пробные точки: пауза, шаг, скорость 1×/2×/4×, переход и rewind по истории. **Повторный пересчёт назад, потоки и физическая анимация не реализованы**. График скорости не синтезируется, так как A4 не поставляет согласованный rate series.

## Запуск в Godot из исходников

Требуются Godot 4.3 и .NET SDK 10 для публикации автономного CLI (SDK не нужен конечному пользователю после публикации):

```bash
dotnet publish src/ChemSim.Kinetics.Cli/ChemSim.Kinetics.Cli.csproj -c Release -r linux-x64 --self-contained true -p:PublishSingleFile=true -o bin
chmod +x bin/chemsim-solver
godot --editor --path .
```

На Windows публикация использует `-r win-x64`, выходной файл `bin/chemsim-solver.exe`. Затем запустите `project.godot` в Godot 4.3, нажмите **«Учебный тест N₂O₄ → 2 NO₂»**, дождитесь внешнего ответа A4 и используйте графики и временную шкалу. Кнопка *не* запускает сырой пользовательский черновик.

`tests/test_integration_smoke.gd` прогоняет настоящий сквозной тест через внешний процесс. CI: [Integrated synthetic A2-A4-A5 smoke](https://github.com/AndreyCokol/ChemSim/actions/workflows/integrated-smoke.yml). Linux E2E и A4 Windows CLI проходили в [run #41667454419](https://github.com/AndreyCokol/ChemSim/actions/runs/41667454419). **Этот предыдущий run не является доказательством экспорта готового Windows Godot-приложения.**

## Безопасность и границы модели

- `N₂O₄` и `NO₂` здесь используются **только как разбираемые A2 формулы и коэффициенты баланса**. Выбранный закон скорости и `k=0.1 s⁻¹` — искусственные тестовые параметры без научного происхождения, в том числе без модели газового равновесия. Не интерпретировать график как предсказание реального разложения/равновесия NO₂.
- Нельзя запускать произвольную реакцию из черновика: отсутствуют утверждённые каталожные параметры, источники/права, условия применимости, общая поддержка A1/A3, механизм выбора кинетической модели и потоков.
- Ошибка/недоступный CLI не превращается в синтетический успешный ряд. Частичный префикс при численной неудаче должен быть помечен как частичный; никогда не заменять неизвестное измеренным нулём.
- Протокол рассчитан на **только локальные** `user://` файлы с непредсказуемым именем. Это пока не полная модель защиты от враждебной файловой системы/симлинков; такие угрозы требуют отдельного аудита и тестирования.
- Размеры/timeout/Windows ZIP не означают гарантированную физическую или численную достоверность за пределами заявленного synthetic fixture.
- Релиз требует самостоятельного подтверждения Windows 10/11 x64 запуска, всех ресурсов и автономного CLI из ZIP, в том числе Unicode-путей и режима полностью отключённой сети.

## Acceptance matrix

| Gate | Test | Evidence |
|---|---|---|
| A2 actual parser and balance | `tests/a2/test_a2_parser_balancer.gd`, `tests/test_integration_smoke.gd` | CI on exact head |
| A4 actual numerical kernel | `tests/ChemSim.Kinetics.Tests/*` | .NET unit tests |
| Godot→A4 actual process and graph | `tests/test_integration_smoke.gd` | Linux E2E on exact head |
| Missing model, incompatible units, malformed response | A4 CLI tests + A5 validator acceptance | Must pass |
| Playback exact validated sample history | `tests/test_integration_smoke.gd` | Step/rewind/seek checks |
| Windows .NET x64 standalone | GitHub Actions `windows-selfcontained-publish` | Windows CLI smoke |
| Windows Godot export + ZIP | `windows-standalone-package-smoke` | **Pending exact run evidence** |
| Scientific kinetics of actual NO₂ | A1/A3/A4 validated properties and model | **NOT READY** |
| Open systems, full rewind/replay | New A4 solver/model and A5 adapter | **NOT READY** |
