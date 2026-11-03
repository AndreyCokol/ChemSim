# Спецификация: Парсер химических уравнений и балансировщик (A2)

> Статус: DRAFT — подготовлено Agent A2 для межагентного ревью и утверждения владельцем. Эта спецификация описывает наблюдаемое поведение; она не утверждает, что все перечисленные возможности уже реализованы.

## Область ответственности

A2 отвечает за преобразование текстовой формулы или уравнения в проверяемое структурированное представление, валидацию введённой стехиометрии, проверку сохранения атомов и заряда, отдельное предложение коэффициентов, диагностику и каноническую сериализацию.

A2 не рассчитывает pH, равновесие, растворимость, осаждение, константы термодинамики или кинетические скорости и не реализует UI, каталог веществ или численный интегратор.

## Термины и базовые правила

- **Формула** — химическая запись вещества без стехиометрического коэффициента.
- **Стехиометрический коэффициент** — положительное целое число перед формулой в уравнении.
- **Индекс** — положительное целое число внутри формулы, задающее количество атомов/групп.
- **Фаза** — отдельное свойство вида `SOLID`, `LIQUID`, `GAS`, `AQUEOUS` или `UNSPECIFIED`.
- **Заряд** — целочисленный суммарный заряд частицы.
- **Балансировка** — отдельная операция, предлагающая коэффициенты; она не является частью парсинга и не переписывает исходное уравнение.

Коэффициенты стехиометрии не задают кинетические порядки. Парсер и балансировщик не должны выводить одно из другого. В текущем API `parse_formula` разбирает только формульную часть; ведущий коэффициент является полем `ReactionTerm` и разбирается `parse_reaction`.

## Requirement: Разбор формул

Система SHALL разбирать формулы из известных символов химических элементов, положительных целочисленных индексов и вложенных круглых групп в пределах документированных ограничений размера и глубины. Коэффициент перед формулой SHALL храниться отдельно от AST формулы.

### Scenario: Индекс и коэффициент
- WHEN пользователь вводит `2H2O`
- THEN система представляет коэффициент 2 отдельно от формулы `H2O`
- AND элементный состав формулы содержит два атома водорода и один атом кислорода
- AND сериализация не переносит коэффициент в индекс и наоборот

### Scenario: Вложенная группа
- WHEN пользователь вводит формулу с корректной вложенной круглой группой, например `Ca(OH)2`
- THEN система вычисляет элементный состав с учётом множителя группы

### Scenario: Неизвестный элемент или некорректный индекс
- WHEN формула содержит неизвестный символ элемента, нулевой/отрицательный индекс, пустую группу или несогласованные скобки
- THEN система отклоняет формулу и возвращает машинно-читаемый код ошибки и диапазон исходного текста

## Requirement: Заряд и фаза

Система SHALL поддерживать явно объявленную грамматику зарядов и фаз. Заряд и фаза SHALL храниться отдельно от дерева атомного состава. Неподдерживаемые или неоднозначные записи SHALL отклоняться, а не интерпретироваться догадкой.

### Scenario: Многоосновный заряд
- WHEN пользователь вводит поддерживаемую запись вида `Fe^3+` или `SO4^2−`
- THEN AST содержит соответствующий целочисленный заряд, а элементный состав не включает символы заряда

### Scenario: Фаза
- WHEN формула оканчивается на `(s)`, `(l)`, `(g)` или `(aq)`
- THEN фаза представляется отдельным значением и не включается в состав формулы

### Scenario: Неподдерживаемая форма частицы
- WHEN пользователь вводит радикал, изотоп, комплекс, гидрат или иную запись вне объявленной грамматики
- THEN система возвращает явную ошибку/диагностику неподдерживаемой конструкции
- AND не подменяет её приблизительной формулой

## Requirement: Разбор уравнений реакции

Система SHALL разбирать уравнение на непустые упорядоченные списки реагентов и продуктов, сохранять коэффициенты, фазы, заряды и тип стрелки. Уравнение SHALL содержать ровно одну стрелку из поддерживаемого набора. Разделитель ионных компонентов SHALL быть отличим от знака заряда.

### Scenario: Простая реакция
- WHEN пользователь вводит `H2 + O2 -> H2O`
- THEN система возвращает два реагента, один продукт и прямую стрелку
- AND не меняет коэффициенты автоматически

### Scenario: Ионная реакция
- WHEN пользователь вводит ионы с однозначным разделителем компонентов, например `NH4+ + Cl- -> NH4Cl`
- THEN система различает знаки зарядов и разделитель между компонентами

### Scenario: Обратимая стрелка
- WHEN пользователь вводит `⇌` или поддерживаемый эквивалент
- THEN структурированная реакция сохраняет признак обратимости/исходную семантику стрелки
- AND A2 не выводит из этого кинетические параметры или равновесную константу K

### Scenario: Некорректная структура уравнения
- WHEN уравнение не содержит стрелку, содержит несколько стрелок, пустую сторону или пустой член
- THEN система отклоняет ввод с кодом ошибки и диапазоном исходного текста

## Requirement: Структурированный DTO реакции

Система SHALL представлять реакцию отдельными списками реагентов и продуктов. Каждый член SHALL содержать parsed species descriptor с FormulaAST и отдельным фазовым контекстом, положительный целочисленный стехиометрический коэффициент и метаданные идентичности исходного члена, если они доступны. В текущей реализации парсера генерируемый `term_id` является локатором только в рамках одного разбора, вычисляемым из символьного смещения в исходном тексте; это не постоянный идентификатор, и он может измениться при редактировании текста. Если вызывающей стороне нужна идентичность между редакциями или сохранёнными сессиями, она MUST управлять собственным стабильным ID вне текущего API парсера. Сохранение внешнего ID будет частью общего DTO/API после его согласования. Для вещества, явно сопоставленного с каталогом, член MAY дополнительно содержать `substance_id` (или интегратором утверждённую версионируемую ссылку); парсер SHALL NOT выводить или создавать такой ID из формулы. Если каталоговое сопоставление не выполнено, член SHALL оставаться unresolved descriptor без фиктивной каталоговой идентичности и без неявной регистрации пользовательского вещества. FormulaAST SHALL содержать версию схемы, исходную формульную запись, дерево узлов, элементный состав и заряд; фаза SHALL оставаться отдельным контекстом вхождения, а не частью FormulaAST или SubstanceRecord identity.

### Scenario: Некорректный коэффициент
- WHEN коэффициент равен нулю, отрицателен, дробный или превышает объявленный предел
- THEN система отклоняет DTO и сообщает причину

### Scenario: Устаревший или изменённый AST
- WHEN AST не соответствует повторному разбору сохранённой исходной формулы
- THEN система отклоняет DTO при проверке баланса, балансировке или сериализации
- AND не доверяет независимо изменённым элементным количествам или заряду

### Scenario: Разделение стехиометрии и кинетики
- WHEN реакция передаётся в кинетическую подсистему
- THEN стехиометрические коэффициенты остаются отдельными полями
- AND не трактуются автоматически как порядки реакции

## Requirement: Проверка атомного и зарядового баланса

Система SHALL проверять сохранение количества каждого элемента и суммарного электрического заряда с учётом введённых коэффициентов. Проверка SHALL быть чистой операцией и не изменять DTO реакции.

### Scenario: Сбалансированная реакция
- WHEN пользователь проверяет корректно сбалансированную реакцию с учётом атомов и заряда
- THEN система сообщает, что реакция сбалансирована, и предоставляет нулевые невязки

### Scenario: Несбалансированная реакция
- WHEN хотя бы одна элементная или зарядовая невязка ненулевая
- THEN система сообщает, что реакция несбалансирована, с диагностикой соответствующих невязок

### Scenario: Несбалансированная ионная реакция
- WHEN атомы совпадают, но суммарный заряд сторон различается
- THEN система помечает реакцию как несбалансированную

## Requirement: Отдельное предложение балансировки

Система SHALL предоставлять явную операцию предложения баланса для корректной реакции. Она SHALL искать положительные целые коэффициенты в пределах объявленных ограничений и минимизировать сумму коэффициентов по различным solver-членам. Результат SHALL быть отдельным объектом-предложением и не SHALL изменять исходные коэффициенты или AST.

### Scenario: Балансировка с неверными введёнными коэффициентами
- WHEN пользователь передаёт `7H2 + 3O2 -> 5H2O` в операцию предложения баланса
- THEN система возвращает предложение `2H2 + O2 -> 2H2O`
- AND исходные коэффициенты 7, 3 и 5 остаются неизменными

### Scenario: Единственный оптимум
- WHEN в минимальном полностью исследованном слое найдена ровно одна положительная целочисленная комбинация
- THEN система возвращает её и указывает, что оптимальность и уникальность доказаны в пределах заявленной задачи

### Scenario: Несколько оптимумов
- WHEN несколько комбинаций имеют одинаковую минимальную сумму коэффициентов
- THEN система возвращает статус неоднозначности и альтернативы
- AND не выбирает произвольный результат как единственно правильный

### Scenario: Исчерпан лимит поиска
- WHEN лимит кандидатов, узлов поиска или суммы коэффициентов не позволяет доказать оптимальность
- THEN система возвращает статус ограничения поиска
- AND не заявляет отсутствие решения, если оно не доказано

### Scenario: Невозможность положительного баланса
- WHEN элемент присутствует только на одной стороне реакции
- THEN система может доказать структурную невозможность положительного баланса и возвращает соответствующий статус

### Scenario: Повторяющиеся члены
- WHEN одна и та же запись формулы и фаза повторяются на одной стороне
- THEN solver может агрегировать такие члены в одну переменную
- AND результат сохраняет идентификаторы всех исходных членов и явно описывает агрегированную семантику
- AND система не распределяет агрегированный коэффициент по исходным членам произвольно

## Requirement: Диагностика и исходные диапазоны

Система SHALL возвращать стабильный код, понятное сообщение и диапазон исходного текста для синтаксических ошибок, когда позиция ошибки определима. Диапазоны SHALL использовать нулевую индексацию и исключительную конечную позицию; единицы смещения — индексы символов Godot `String` (не UTF-8 байты), единообразные для формул и полных строк уравнений.

### Scenario: Ошибка внутри формулы
- WHEN пользователь вводит ошибочную группу или заряд
- THEN диапазон диагностики указывает на проблемный фрагмент исходной строки

### Scenario: Ошибка в уравнении
- WHEN ошибка находится после начала правой стороны или около стрелки/разделителя
- THEN смещения относятся ко всему исходному уравнению, а не только к локальному фрагменту стороны

## Requirement: Каноническая сериализация

Система SHALL сериализовать только валидные структурированные формулы и реакции. Сериализация SHALL сохранять химическую семантику коэффициента, индексов, заряда, фазы и типа стрелки. Некорректный или устаревший DTO SHALL приводить к явной ошибке/пустому результату согласно контракту API, но не к выдаче правдоподобной некорректной строки.

### Scenario: Round-trip
- WHEN валидная формула или реакция разбирается и затем канонически сериализуется
- THEN повторный разбор сериализованной строки восстанавливает эквивалентную структуру

## Поддерживаемая грамматика текущего MVP

Подтверждённый текущим A2 README поднабор:
- символы элементов периодической таблицы; `parse_formula` принимает только формулу без стехиометрического коэффициента, а коэффициент разбирается на уровне члена реакции (`parse_reaction`);
- положительные целочисленные индексы;
- вложенные круглые группы;
- фазы `(s)`, `(l)`, `(g)`, `(aq)`;
- явно записанные заряды вида `Fe^3+`, `SO4^2−` и allowlist однозарядных ионов: `H+`, `OH-`, `NH4+`, `Ag+`, `Cl-`, `Na+`, `K+`, `Li+`, `NO3-`, `NO2-`, `HCO3-`, `CH3COO-`;
- стрелки `->`, `→`, `⇌`, `<->`; DTO нормализует их до `FORWARD` или `REVERSIBLE`, поэтому точный исходный глиф стрелки не сохраняется, а сериализатор использует канонические `->` / `⇌`;
- разделитель компонентов `+` с пробелами вокруг него в текущем текстовом синтаксисе.

Текущий MVP не включает квадратные скобки комплексов, гидраты, изотопы, радикалы, ионно-электронную балансировку и расширенную органическую нотацию. Это ограничения реализации, а не утверждение о химической невозможности таких записей.

## Межагентное ревью: подтверждённая позиция A3 (2026-11-03)

A3 предоставил provisional consumer contract в `docs/agents/a3-equilibrium-core.md` (commit `4b406407cfb671106250dee3cb1be74449352bfc`) и уточнил source-term identity (commit `a24321df3f6ac9ce210d18eb78668a9ea16d19a7`). Это позиция потребителя, а не утверждение общего DTO:

- Для parser-to-equilibrium adapter A3 нужны валидированный species descriptor (FormulaAST/element composition, integer charge, отдельная occurrence phase), положительный stoichiometric coefficient, side/direction и mapping исходных членов/дубликатов.
- Перед созданием closed-system equilibrium problem A2 balance validation (elements + charge) должна пройти; A3 boundary вправе независимо перепроверять баланс.
- Равновесная константа должна поступать как явная ссылка/параметр с направлением реакции, basis и standard state. Стрелка обратимости сама по себе не является K; A2 не выводит K или кинетические параметры.
- Для hypothetical calculations отсутствие catalog `substance_id` допустимо, если unresolved descriptor валиден и thermodynamic model располагает необходимыми данными. A2 не создаёт фиктивные ID.
- Parse-local `term_id` достаточен для численного решения и диагностики конкретного текста. Постоянный ID, если он нужен для редакций/экспериментов/provenance, назначается caller/experiment layer на adapter boundary; mapping должен сохранять все исходные локаторы и дубликаты.
- A3 может агрегировать дубликаты только после установления эквивалентности identity и phase. Текущие A3 fixtures пока не потребляют A2 DTO напрямую.
- A3 downstream-конвенции включают `H+`, `OH−`, unit water activity и узкие предположения текущего AgCl fixture. Это не расширяет грамматику A2 и не превращает parser в equilibrium model.

**Принято A2:** требования к composition/charge/phase/coefficient/side/source mapping и parse-local locator отражены в A2 spec. K reference, basis, standard state, water activity и модельные ограничения остаются данными/ответственностью A3 и интегратора, а не полями, выводимыми парсером.

## Решения, требующие межагентного согласования

1. **Каталоговая идентичность.** A1 подтвердил логическую позицию: `substance_id` опционален и появляется только после явного catalog lookup/selection; unmatched formula остаётся unresolved species descriptor. Формула не является ID. Правила сопоставления разных записей и окончательная форма ссылки остаются за A1/интегратором.
2. **Reaction DTO и идентичность членов.** Согласовать обязательные поля с интегратором. Текущий `term_id` — parse-local locator, достаточный для диагностики по конкретному исходному тексту; A3 подтвердил, что постоянный ID на этапе парсинга ему не нужен. Если приложению требуется идентичность между редакциями/сохранёнными экспериментами, слой приложения/эксперимента назначает собственный стабильный ID на adapter boundary и хранит отображение на актуальные parse-local locator(s). Не выводить постоянные ID из offset, формулы или коэффициента. Реакция/член могут иметь версионированные стабильные ID только по решению общего DTO-контракта.
3. **Обратимые реакции.** A2 сохраняет тип стрелки; A3 владеет термодинамическим равновесием, A4 — кинетической интерпретацией. K и кинетические параметры не принадлежат парсеру.
4. **Заряд и разделители.** A3 подтвердил, что downstream-конвенции включают shorthand `H+` и `OH−`; A2 уже поддерживает эти алиасы и разделитель `+` с пробелами вокруг. Нужен общий интеграционный набор тестов для ионных формул, Unicode-вариантов минуса и неоднозначных строк с символом `+`.
5. **Дубликаты.** A1 и A3 согласны, что исходные члены и их локаторы должны сохраняться. Solver-side aggregation допустима только после проверки эквивалентности identity/formula и phase и при сохранении всех исходных locator(s) и caller-owned stable ID(s); произвольное обратное распределение агрегированного коэффициента запрещено. Окончательный DTO mapping остаётся за интегратором.
6. **Область валидности.** Перечень поддерживаемых веществ/нотаций должен совпадать с доменной моделью A1; парсер не должен считать синтаксическую корректность доказательством физической реализуемости реакции.
7. **Фазовый wire contract.** A1 подтвердил фазу как контекст Species/ReactionTerm, но не утвердил общий enum/wire vocabulary. Текущий A1PhaseAdapter — временный compatibility adapter; интегратор должен выбрать единый typed enum и определить владельца adapter/call site. `UNSPECIFIED` необходимо сохранять явно и не угадывать.

## Эталонные тестовые векторы

| Категория | Вход | Ожидаемое поведение |
|---|---|---|
| Простая формула | `H2O` | H:2, O:1 |
| Коэффициент отдельно от индекса | `2H2O` | coefficient=2; H:2, O:1 в FormulaAST |
| Вложенная группа | `Ca(OH)2` | Ca:1, O:2, H:2 |
| Заряд | `Fe^3+` | charge=+3 |
| Фаза | `CO2(g)` | phase=GAS; состав CO2 |
| Простое уравнение | `H2 + O2 -> H2O` | parse succeeds; balance check false |
| Ионное уравнение | `Ag+ + Cl- -> AgCl(s)` | parse succeeds; charge/phase retained |
| Нейтрализация | `H+ + OH- -> H2O` | both one-charge aliases parse; atom/charge balance can be checked independently |
| Обратимая стрелка | `N2(g) + 3H2(g) ⇌ 2NH3(g)` | reversible arrow retained; no K or kinetics inferred |
| Балансировка | `H2 + O2 -> H2O` | propose 2,1,2 |
| Зарядовая невязка | `Fe^3+ + 2Cl- -> FeCl2` | parse succeeds; atom counts match, charge residual is +1, so balance check is false; electron notation is outside this MVP |
| Неверный коэффициент | `0H2 + O2 -> H2O` | rejected |
| Пустая сторона | `H2 + O2 ->` | rejected with source span |
| Несколько стрелок | `H2 -> H2 -> H2` | rejected |
| Несбалансированный заряд | `Na+ + Cl- -> Na+` | atom/charge balance reports residual |
| Повторный член | `H2 + H2 + O2 -> H2O` | two H2 source terms remain distinct in the input DTO; solver aggregates them into one variable with both source IDs; proposed aggregate coefficient is 2; no arbitrary split back to source terms |

## Serializer contract — Reaction DTO versioning (A2 audit, 2026-11-03)

The canonical reaction DTO emitted by `parse_reaction()` carries top-level `schema_version = 1`. A serializer must fail closed for a missing, non-integer, or unsupported top-level Reaction DTO schema version; it must not silently treat an unversioned or newer DTO as version 1. For the current v1 implementation, `serialize_reaction()` returns an empty string for any reaction DTO whose top-level `schema_version` is not the integer `1`.

Required A2 regression cases before implementation approval:
- Parsed v1 reaction DTO serializes to the existing canonical string.
- Removing top-level `schema_version` makes serialization fail (empty string).
- Setting top-level `schema_version` to unsupported integer `2` makes serialization fail.
- Setting top-level `schema_version` to a non-integer value makes serialization fail.
- Existing malformed/stale FormulaAST, phase, arrow, term, and round-trip rejection tests continue to pass.

This is a focused A2-owned serializer invariant and does not define shared DTO version negotiation, migration, ErrorEnvelope versioning, or compatibility policy. Those remain integrator decisions. The finding was verified against the current A2 branch: `parse_reaction()` emits version 1, while `serialize_reaction()` currently validates sides, arrow and terms but omits the top-level version check. Implementation and tests remain gated by product-owner approval of this DRAFT OpenSpec.

## DRAFT: Fail-closed validation of externally supplied Reaction DTO (A2 audit, 2026-11-03)

**New, source-confirmed contract gap; proposed acceptance only.** `parse_reaction()` produces the top-level fields `schema_version = 1`, `arrow_type`, `reactants` and `products`, and each `ReactionTerm` has explicit `stoichiometric_coefficient` and `species.phase`. But the current public A2 entry points accept some malformed, caller-built versions:

- `check_balance()` and `propose_balance()` validate term content but do not require the reaction's top-level `schema_version` or `arrow_type`; `serialize_reaction()` likewise omits the top-level version guard (already tracked above).
- `serialize_reaction()` defaults an absent `arrow_type` to `FORWARD`, potentially rewriting a malformed/reversible DTO as irreversible rather than failing.
- The A2 term validators use default `stoichiometric_coefficient = 1` and `species.phase = UNSPECIFIED` when these fields are missing. As a result, a missing coefficient/phase can be silently interpreted rather than diagnosed (for an originally phase-unspecified formula, the default phase may even reparse successfully).

**Proposed A2 v1 rule, pending owner approval:** on **externally supplied Reaction DTOs**, the three public consumer operations (`check_balance`, `propose_balance`, `serialize_reaction`) SHALL require a literal integer top-level `schema_version = 1`, a present valid `arrow_type`, explicit positive-integer `stoichiometric_coefficient` per term, and explicit `species.phase` (including the literal `UNSPECIFIED` when no phase was written). Missing data SHALL NOT be synthesized from defaults. This does not prohibit the text parser from assigning coefficient 1 or phase `UNSPECIFIED` during **parsing**, since that successful parse yields an explicit, versioned DTO. No migration or shared-wire contract is implied.

Proposed regression matrix for a **single parsed v1** fixture such as `2H2 + O2 -> 2H2O` (clone before each mutation):

| Mutation | `check_balance` | `propose_balance` | `serialize_reaction` |
|---|---|---|---|
| None (valid v1, explicit fields) | `ok=true`, balanced | `UNIQUE_OPTIMUM` | canonical string |
| Remove top-level `schema_version` | `BALANCE_INVALID_REACTION` | `INVALID_INPUT` | empty string |
| Set `schema_version=2` or `"1"` | `BALANCE_INVALID_REACTION` | `INVALID_INPUT` | empty string |
| Remove `arrow_type` | `BALANCE_INVALID_REACTION` | `INVALID_INPUT` | empty string |
| Remove a term's `stoichiometric_coefficient` | `BALANCE_INVALID_TERM` | `INVALID_INPUT` | empty string |
| Remove `species.phase` on a phase-unspecified term | `BALANCE_INVALID_TERM` | `INVALID_INPUT` | empty string |

These are **expected future behaviours**, not current test results. They should not be implemented until the product owner approves/revises this DRAFT. Error codes shown are existing A2-local codes, not the undecided shared `ErrorEnvelope`. If legacy/unversioned caller DTOs must be supported, the integrator must define an explicit validated conversion before entering the versioned A2 API; silent defaults at this boundary remain unsafe.

## Межагентное ревью: подтверждённый consumer contract A4 (2026-11-03)

A4 опубликовал implementation-aligned consumer contract в `docs/engineering/a4-kinetics-input-contract.md` (ветка `feature/a4-kinetics-core`, commit `56f4011ed92fb7112c8c04cddb941bce40e4defc`). Это описание текущего A4-среза, а не утверждение общего DTO или baseline.

Подтверждённая граница для A2 → A4:

- A2 предоставляет проверяемую формульную композицию и целочисленный заряд в FormulaAST, отдельный occurrence phase, положительный целочисленный стехиометрический коэффициент, сторону/направление через структуру Reaction DTO и parse-local source locator(s).
- A4 ReactionDefinition использует знаковые стехиометрические коэффициенты (реагенты отрицательные, продукты положительные), explicit kinetic-order map keyed by species ID и RateConstant. Следовательно, знак/ID mapping и преобразование A2-side lists в A4 network — ответственность adapter/caller, а не парсера.
- Kinetic orders независимы от стехиометрии; A2 не выводит их из коэффициентов или стрелки. A2 также не выводит RateConstant, его единицы, температурную поправку или equilibrium K.
- Текущий A4 solver ограничен closed, well-mixed, constant-volume, isothermal power-law моделью. Adapter обязан проверить species/network identity, полное начальное состояние, явные конверсии amount/volume/time, dimensional compatibility и model applicability.
- Provenance, uncertainty, quality/review, validity range и redistribution/license остаются A1-owned upstream concerns; текущий A4 RateConstant их не хранит и не валидирует.
- A4 SimulationResult может содержать валидный prefix при non-success status; downstream обязан сохранять status/diagnostics и не трактовать частичный профиль как завершённую траекторию.

**Принято A2 как consumer boundary:** текущий A2 FormulaAST/ReactionTerm набор не требует добавления кинетических полей или нового parser-owned идентификатора. Caller/adapter отвечает за стабильные species IDs, знак стехиометрии для A4 и преобразование DTO. Parse-local locators остаются диагностической привязкой к исходному тексту. Фазу и все source locators необходимо сохранить на общей границе; точный mapping/aggregation policy должен быть закреплён интегратором.

Это подтверждение закрывает запрос A2 к A4 по минимальному parser-consumer набору на уровне текущей модели. Оно **не** утверждает shared Reaction DTO, canonical phase wire enum, Unit Registry, ErrorEnvelope, общую schema-version policy или adapter ownership.

## Ограничения и риски

- Балансировка — ограниченный точный перебор, а не универсальный ILP solver; статус ограничения поиска не эквивалентен отсутствию решения.
- Минимизация суммы коэффициентов зависит от определения «различного solver-члена» и правил агрегации дублей.
- Формульная идентичность не различает изомеры и не заменяет Substance ID.
- Синтаксически корректная формула/реакция не гарантирует химическую возможность процесса.
- Парсер не проверяет термодинамическую допустимость, фазовое равновесие или кинетическую реализуемость.
- До интеграции требуется ревью точности смещений, диапазонов чисел, арифметических границ и семантики дублирующихся членов.

## Статус и критерии выхода из DRAFT

Спецификация остаётся DRAFT. A1 дал логическую позицию по Substance ID, unresolved descriptors и duplicate-term policy; A3 дал provisional consumer requirements и подтвердил достаточность parse-local locator для численного решения. Эти позиции отражены здесь, но общий DTO и OpenSpec baseline не утверждены. A4 подтвердил текущий consumer contract и минимальные parser-consumer данные; это отражено выше. Решения интегратора по canonical phase wire contract, adapter/call-site ownership, shared Reaction DTO/schema versioning, Unit Registry и ErrorEnvelope всё ещё ожидаются. До утверждения:
- реализация не расширяется новыми химическими возможностями;
- межагентные DTO-контракты не объявляются окончательными;
- открытые решения фиксируются как вопросы, а не закрываются предположениями.

Спецификация может перейти в статус APPROVED после согласования Reaction DTO, Substance ID, дубликатов, обратимых стрелок и набора эталонных тестов владельцем продукта.