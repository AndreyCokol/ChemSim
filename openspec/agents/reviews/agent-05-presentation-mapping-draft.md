# A5 — Presentation Mapping Draft for Round 2

Дата: 2026-11-02  
Репозиторий: AndreyCokol/ChemSim  
Ветка: agent/a5-ux-integration-review  
Статус: **proposal / contract-dependent / not approved**  
Назначение: определить, как UI отображает согласованные данные A1–A4 и Application Layer. Этот документ не утверждает DTO, enum, поля сериализации или API.

## 1. Правила чтения

- Названия сущностей взяты из рабочего decision register и профильных предложений.
- Любое поле, enum или код ошибки остаётся условным, пока его владелец и интегратор не утвердят нормативную схему.
- UI не восстанавливает отсутствующую химию, не пересчитывает равновесие/кинетику и не меняет научную семантику входных данных.
- Неизвестное значение не равно нулю; отсутствие данных не означает безопасность или неприменимость.
- Единицы отображения могут меняться, но canonical value и simulation identity от этого не меняются.

## 2. Карта объектов и экранов

| Domain/application object | Экран / UI control | Что показываем | Что UI не делает |
|---|---|---|---|
| SubstanceRecord + revision | Encyclopedia / Substance details | имя, ID, FormulaAST display, record revision, пользовательская/встроенная запись | не задаёт фазу экземпляра и количество опыта |
| PropertyRecord | Property table | значение, единица, basis, условия, validity, uncertainty status, provenance, data quality | не объединяет все свойства в одну «достоверность вещества» |
| SpeciesRef | Reaction editor / species picker | формула + фаза контекста + стабильная ссылка/alias | не выводит фазу только из цвета или карточки Substance |
| ReactionTerm | Reaction editor | вид, фаза, стехиометрический коэффициент; kinetic order — отдельное поле только при наличии A4-модели | не выводит кинетический порядок из коэффициента |
| ExperimentComponent | Experiment setup / calculation panel | количество и выбранные параметры состояния; ссылка на SpeciesRef | не записывает amount/concentration/layout в SubstanceRecord |
| EquilibriumProblem / Result | Equilibrium details | basis, standard state, activity model, assumptions, residual/status, applicability | не подменяет thermodynamic pH concentration shortcut |
| KineticModel / KineticParameterSet | Kinetics details | rate-law name/version, orders, rate basis, k unit, reference T, validity, provenance | не предполагает s^-1 для любого k; не приравнивает kf/kr к K автоматически |
| SimulationState / SolverResult | Timeline + results | model time, lifecycle, termination reason, numerical estimate, residuals, sample validity | не смешивает solver convergence с научной применимостью |
| DiscreteEvent / FlowSchedule | Timeline / event list | timestamp, canonical order/index, type, parameters, acknowledgement | не сортирует события по названию/позиции UI |
| ErrorEnvelope | Diagnostics + inline field state | stable code, severity, message, context, missing fields, source refs, recoverability | не создаёт отдельный A5 error DTO |
| ReliabilityVector | Result header / per-series badge | data quality, model validity, numerical status, completeness, warnings | не показывает процент точности и не сливает измерения |
| ReplayMetadata / history | History & replay | model/data versions, solver settings, input snapshot identity, restore/recompute mode | не обещает bitwise determinism без гарантии A4 |
| UI layout document | Workspace | positions, window state, selected tabs, graph zoom/visibility | не включается в simulation hash |

## 3. Substance, Species и ExperimentComponent — критическая UX-граница

Одна формула может встречаться в нескольких фазовых контекстах и нескольких экспериментах. UI должен отражать три уровня:

1. **SubstanceRecord:** справочная сущность каталога.
2. **SpeciesRef:** химическая частица в контексте реакции/равновесия; фаза задаётся здесь/в ReactionTerm согласно финальному контракту.
3. **ExperimentComponent:** конкретное участие в эксперименте с количеством и состоянием.

### Пример отображения (концептуальный)

- В каталоге: **Вода · H₂O** — SubstanceRecord.
- В редакторе реакции: **H₂O(l)** или **H₂O(g)** — SpeciesRef/ReactionTerm; это разные контексты участия.
- В составе эксперимента: **H₂O(l), 0.50 mol** — ExperimentComponent.

UI не должен:
- создавать две независимые каталоговые сущности только из-за различия фазы;
- терять фазу при переходе из редактора реакции в расчёт;
- изменять количество вещества в каталоге при редактировании эксперимента;
- считать визуальные координаты идентификатором химической частицы.

## 4. Property table и происхождение данных

Каждая строка свойства должна иметь минимум три визуальных слоя:

- **Значение:** форматированное число + единица, basis/условия рядом, если они влияют на интерпретацию.
- **Качество утверждения:** reported / estimated / user-entered / unknown или иные финальные статусы A1 (названия пока не фиксируются).
- **Происхождение:** источник/версия/дата и лицензионная доступность там, где применимо.

Поведение:
- неизвестная неопределённость отображается как «не сообщена», а не как нулевая;
- отсутствующее значение не скрывается, если от него зависит расчёт или понимание полноты записи;
- несовместимая размерность приводит к диагностике и блокировке использования, а не к молчаливому преобразованию;
- условия и диапазон применимости должны быть доступны до запуска расчёта;
- provenance пользовательского значения обозначается как введённое пользователем, без выдуманного источника.

## 5. Reaction editor и парсер

### Разделение действий

- Ввод/редактирование уравнения.
- Разбор (если отдельная команда будет предусмотрена API).
- Балансировка — только отдельное явное действие.
- Принятие результата балансировки — отдельное подтверждение пользователя.

### Представление диагностики

Если A2 передаёт token/span offsets, UI выделяет точный диапазон исходного текста. Если передан только общий контекст, UI показывает сообщение без выдуманной подсветки. Стабильный machine code сохраняется для логов/тестов, пользовательское сообщение локализуется через message key.

### Семантика термов

- FormulaAST отвечает за состав и net charge согласно A2.
- Фаза отображается отдельно.
- Стехиометрический коэффициент и kinetic order визуально и семантически разделены.
- Неоднозначность заряда, фазы или группировки не исправляется автоматически.

## 6. Equilibrium result view

Обязательные блоки результата:

1. **Модель и предположения:** aqueous activity model или ideal-dilute assumption; ideal-gas/partial-pressure assumption для газовой модели.
2. **Базис:** equilibrium constant basis и standard state в терминологии A3.
3. **Условия:** T, P, объём/среда — только фактически использованные параметры.
4. **Результат:** состав/концентрации/активности с typed units и признаком sample validity.
5. **Численная диагностика:** convergence/status/residuals — из A3, без UI-пересчёта.
6. **Применимость:** диапазон и предупреждения.

pH:
- label и пояснение следуют конвенции A3;
- концентрационное приближение должно иметь явное имя;
- UI не подписывает -log10[H+] как универсальный термодинамический pH.

## 7. Kinetics, graph adapter и timeline

### GraphSeries mapping

UI adapter ожидает от согласованного контракта:
- стабильную series identity;
- owner/quantity semantics (species concentration, species formation/consumption rate, reaction progress rate и т.п.);
- typed unit/dimension;
- model-time coordinate;
- sample value либо explicit missing/invalid state;
- provenance/model revision/quality metadata;
- event reference, если sample связан с событием.

До утверждения rate semantics A5 не задаёт подписи оси «скорость» и размерности k. В графике нельзя объединять разные rate quantities только потому, что они численно похожи.

### Missing samples

- missing/unknown/invalid не заменяются нулём;
- разрывы линии сохраняются;
- интерполяция запрещена, если её политика явно не задана источником данных/контрактом;
- tooltip показывает исходный статус sample;
- sample с несовместимой revision не смешивается с текущей серией без явного обозначения.

### Shared timeline

Один общий model-time cursor управляет всеми графиками и числовыми панелями. Курсор привязан к experiment identity + model revision + history/replay revision. При несовместимости revisions UI показывает stale/incompatible state, а не пытается «подружить» точки.

### Температура MVP

Temperature series отображает одну заданную постоянную T с подписью «Изотермическая модель». Она не должна визуально создавать впечатление нагрева/охлаждения. Отображение °C/K — преобразование единиц представления, не изменение модели.

## 8. Error Envelope → Diagnostics mapping

| Error envelope element (proposed) | UI mapping |
|---|---|
| machine code | стабильный код в раскрываемых подробностях/логах |
| severity | blocker / error / warning / info после согласования severity enum |
| message key | русское локализованное сообщение |
| context | пояснение с именами затронутых объектов |
| missing field refs | ссылка/фокус на конкретное поле |
| source refs | переход к источнику/свойству/версии |
| recoverability | допустимое действие: исправить вход, выбрать другую модель, повторить, открыть справку |
| subsystem/owner | указание подсистемы для диагностики |

Правила:
- blocker блокирует только зависимую операцию, не сохранение неполной пользовательской записи;
- warning не блокирует запуск автоматически;
- UI не предлагает retry, если ошибка не recoverable;
- текст диагностики не должен обещать, что действие исправит научную ошибку, если это не следует из кода/контекста;
- A5 не меняет machine code и не выводит причину только из текста сообщения.

## 9. ReliabilityVector — два независимых уровня

**Property DataQuality** относится к конкретному свойству/утверждению.  
**Result ReliabilityVector** относится к конкретному вычисленному результату и агрегирует фактически использованные данные, модель, численный статус, полноту и предупреждения.

UI показывает:
- верхний summary label только как словесное резюме по согласованной таблице соответствий;
- отдельные измерения с собственными статусами;
- список фактически использованных допущений и источников;
- отдельный статус каждого графического ряда/результата, если он отличается.

Не использовать:
- «точность 93%»;
- один цветной индикатор без раскрываемых причин;
- наследование статуса всей записи из одного свойства;
- трактовку численной сходимости как доказательства физической применимости.

## 10. Save/load/replay mapping

| Logical document part | UI responsibility | Compatibility rule |
|---|---|---|
| ExperimentDocument | сохранить состав, условия, реакции и ссылки на версии | проверять schema/model/data refs |
| ReplayMetadata/history | показать происхождение расчёта и доступность restore/recompute | не подменять историю новым пересчётом |
| User annotations | сохранить заметки/описания пользователя | не менять chemical identity/hash |
| UILayoutDocument | окна, панели, координаты, zoom, selection | не влияет на simulation hash |

Неизвестная будущая schema version:
- не открывать в режиме редактирования с best-effort интерпретацией;
- не перезаписывать исходный файл;
- показывать совместимый read-only/blocked путь только если это допускает финальная политика;
- предлагать экспорт/копию до миграции, если это предусмотрено persistence contract.

Миграция:
- должна быть атомарной и проверяемой;
- UI показывает source version и target version;
- при ошибке сохраняет оригинал;
- повторный запуск миграции не должен портить документ.

## 11. UX acceptance scenarios для Round 2

| ID | Сценарий | Ожидаемое поведение |
|---|---|---|
| A5-CM-01 | Одна SubstanceRecord используется как aqueous и gas species | общий каталоговый объект; отдельные phase contexts; корректные ссылки |
| A5-CM-02 | Два эксперимента используют одно вещество с разным количеством | независимые ExperimentComponent |
| A5-CM-03 | Свойство имеет unknown uncertainty | UI показывает «не сообщена», не ноль |
| A5-CM-04 | Свойство отсутствует, но не требуется выбранной модели | запись сохраняется; операция не блокируется |
| A5-CM-05 | Свойство отсутствует и требуется модели | точная blocker-диагностика с полем |
| A5-CM-06 | FormulaAST имеет charge, phase задан отдельно | UI не дублирует charge и не теряет phase |
| A5-CM-07 | Балансировка неоднозначна | UI требует разрешения неоднозначности, не выбирает сам |
| A5-CM-08 | Thermodynamic basis несовместим | блокировка с указанием basis/standard state |
| A5-CM-09 | pH — ideal concentration approximation | подпись явно сообщает приближённую конвенцию |
| A5-CM-10 | Rate series имеет неизвестную семантику | не показывать универсальную подпись/единицу «скорость» |
| A5-CM-11 | Временной ряд содержит missing sample | линия имеет gap, tooltip сохраняет статус |
| A5-CM-12 | Solver сошёлся, но модель вне применимости | численный и научный статусы показаны отдельно |
| A5-CM-13 | Два события имеют одинаковый timestamp | UI отображает canonical order из Application/A4 |
| A5-CM-14 | Перемещение вокселя | не меняется chemical state, model revision или simulation hash |
| A5-CM-15 | Изменение UI units/zoom | не меняет canonical values/hash |
| A5-CM-16 | Rewind по сохранённой истории | восстанавливается сохранённый snapshot/history cursor |
| A5-CM-17 | Recompute from start | отдельная операция с явной версией модели/данных |
| A5-CM-18 | Unknown future schema | исходник не перезаписывается; показана несовместимость |
| A5-CM-19 | Hazard record отсутствует | отображается not assessed/no data, не «безопасно» |
| A5-CM-20 | License status unknown | поле может быть видно в локальной записи, но не заявляется как разрешённое для bundled catalog |

## 12. Контрактные вопросы, которые должны быть закрыты до реализации

### A1 + A2
- Каноническая связь SubstanceRecord ↔ FormulaAST ↔ SpeciesRef?
- Какой стабильный Species ID/semantic identity используется?
- Как UI различает неизвестную фазу и фазу not applicable?
- Какие offsets/span semantics гарантирует ParserDiagnostic?

### A3
- Финальный enum equilibrium basis и standard-state identifiers?
- Как кодируются pH conventions и activity-model applicability?
- Какие residuals/statuses являются пользовательски значимыми?

### A4
- Rate quantity taxonomy и typed units?
- KineticParameterSet: reference temperature, Ea, validity, reverse law?
- SolverResult: termination, error estimate, invariants, sample validity?
- Event ordering and replay determinism guarantee?

### Integrator / Application
- Канонический Unit Registry и affine conversion policy?
- Missing/null/unknown enum and field-presence semantics?
- ErrorEnvelope schema and stable code namespace?
- Schema compatibility/migration policy?
- Experiment/model/history revision identity and simulation hash canonicalization?

### A5 / owner
- Final Russian labels and severity-to-action mapping?
- Layout persistence compatibility and keyboard navigation requirements?
- Approval of screen-level acceptance criteria?

## 13. Approval boundary

Этот документ фиксирует только отображение и пользовательское поведение как proposal. Он не утверждает:
- публичные DTO или сериализацию;
- химические модели, уравнения или единицы;
- solver policy, numerical tolerances, event ordering или replay guarantee;
- перечень лицензированных источников;
- OpenSpec baseline и право начинать реализацию.

**Implementation gate remains closed until explicit owner approval of the OpenSpec baseline.**
