# Спецификация: Парсер химических уравнений и балансировщик (A2)

> Статус: **приложение A2 к утверждённому архитектурному baseline v0.1**. Владелец утвердил OpenSpec в `main/openspec/changes/define-chemsim-mvp/APPROVAL.md` (2026-11-03; baseline `02b8b31706807279ee31a78772383e31f425f7d3`) и разрешил поэтапную реализацию A1–A5. Локальные правила A2, помеченные как реализованные, подтверждаются отдельным CI; остальные общие DTO/интеграционные предложения требуют согласования. Этот документ не объявляет весь модуль или MVP завершённым.

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

### Scenario: Однозарядная формула с индексом не превращается в неоднозначную запись
- WHEN A2 разбирает `SO4^-(aq)`, `H2^+(g)`, `Fe2^+` или `Fe2^-(aq)`
- THEN `serialize_formula` сохраняет каноническое `^+`/`^-`, повторный `parse_formula` принимает строку и воспроизводит те же `element_counts`, `net_charge`, `nodes` и фазу
- AND сериализатор не превращает `SO4^-` в `SO4-`, который парсер намеренно отклоняет с `PARSE_AMBIGUOUS_CHARGE`

### Scenario: Поддерживаемые однозарядные алиасы сохраняются
- WHEN исходная формула канонизируется в `NH4+`, `OH-`, `Ag+` из текущего `SIMPLE_ION_ALIASES`
- THEN повторный разбор поддерживается без потери состава и заряда
- AND локальная canonical serialization **не** объявляет окончательный набор алиасов общего wire-контракта; выбор INT-28/29 остаётся у интегратора

**Реализация и проверка A2:** исправление `serialize_formula` commit `7514e6e8a22182e6e01349bf4103cf452867d248`; 11 положительных формульных векторов + round-trip реакции и отрицательный `SO4-` в `tests/a2/test_a2_parser_balancer.gd`, commit `1a0f175d0f3148e49250ed332a922bbdc6220b4e`. Exact source/test HEAD прошёл [Godot CI #41662285747](https://github.com/AndreyCokol/ChemSim/actions/runs/41662285747). Это тесты локального A2 v1 и не подтверждение общей обменной схемы.

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

A2 regression cases, implemented and checked by Godot 4.3 workflow [#41657267795](https://github.com/AndreyCokol/ChemSim/actions/runs/41657267795) on source/test HEAD `dd3de4b396e9a38fe0fccb0f043159ac396fadc6`:
- Parsed v1 reaction DTO serializes to the existing canonical string.
- Removing top-level `schema_version` makes serialization fail (empty string).
- Setting top-level `schema_version` to unsupported integer `2` makes serialization fail.
- Setting top-level `schema_version` to a non-integer value makes serialization fail.
- Existing malformed/stale FormulaAST, phase, arrow, term, and round-trip rejection tests continue to pass.

This is an A2-local v1 serializer invariant, now enforced by `serialize_reaction()` together with the existing formula/term checks. It does **not** define shared DTO version negotiation, migration, ErrorEnvelope versioning, or compatibility policy, which remain integrator-owned. The product-owner baseline approval permits scoped A2 code/testing, but it is **not** proof of the common adapter or integrated Godot↔.NET execution.

## Реализовано: Fail-closed validation of externally supplied Reaction DTO (A2 audit/fix, 2026-11-03)

**Исторический аудит до исправления:** `parse_reaction()` already emitted `schema_version = 1`, `arrow_type`, `reactants` and `products`; each `ReactionTerm` already supplied explicit `stoichiometric_coefficient` and `species.phase`. The previous public A2 entry points nevertheless accepted malformed caller-built DTOs with missing fields. All three defects listed next were corrected in A2 code commits `aa8a147` / `9a42aab` and regression tests commit `dd3de4b`:

- `check_balance()` and `propose_balance()` validate term content but do not require the reaction's top-level `schema_version` or `arrow_type`; `serialize_reaction()` likewise omits the top-level version guard (already tracked above).
- `serialize_reaction()` defaults an absent `arrow_type` to `FORWARD`, potentially rewriting a malformed/reversible DTO as irreversible rather than failing.
- The A2 term validators use default `stoichiometric_coefficient = 1` and `species.phase = UNSPECIFIED` when these fields are missing. As a result, a missing coefficient/phase can be silently interpreted rather than diagnosed (for an originally phase-unspecified formula, the default phase may even reparse successfully).

**Действующее локальное правило A2 v1 под утверждённым baseline:** on **externally supplied Reaction DTOs**, the three public consumer operations (`check_balance`, `propose_balance`, `serialize_reaction`) SHALL require a literal integer top-level `schema_version = 1`, a present valid `arrow_type`, explicit positive-integer `stoichiometric_coefficient` per term, and explicit `species.phase` (including the literal `UNSPECIFIED` when no phase was written). Missing data SHALL NOT be synthesized from defaults. This does not prohibit the text parser from assigning coefficient 1 or phase `UNSPECIFIED` during **parsing**, since that successful parse yields an explicit, versioned DTO. No migration or shared-wire contract is implied.

Implemented regression matrix for a **single parsed v1** fixture such as `2H2 + O2 -> 2H2O` (clone before each mutation):

| Mutation | `check_balance` | `propose_balance` | `serialize_reaction` |
|---|---|---|---|
| None (valid v1, explicit fields) | `ok=true`, balanced | `UNIQUE_OPTIMUM` | canonical string |
| Remove top-level `schema_version` | `BALANCE_INVALID_REACTION` | `INVALID_INPUT` | empty string |
| Set `schema_version=2` or `"1"` | `BALANCE_INVALID_REACTION` | `INVALID_INPUT` | empty string |
| Remove `arrow_type` | `BALANCE_INVALID_REACTION` | `INVALID_INPUT` | empty string |
| Remove a term's `stoichiometric_coefficient` | `BALANCE_INVALID_TERM` | `INVALID_INPUT` | empty string |
| Remove `species.phase` on a phase-unspecified term | `BALANCE_INVALID_TERM` | `INVALID_INPUT` | empty string |

These local A2 v1 cases are **implemented and tested**, including wrong-type versions, unknown arrows and invalid phases (nine negative mutations × three public operations) in the exact source/test commit `dd3de4b396e9a38fe0fccb0f043159ac396fadc6`, CI [#41657267795](https://github.com/AndreyCokol/ChemSim/actions/runs/41657267795) completed successfully. Error codes shown are A2-local and not the shared `ErrorEnvelope`. If legacy/unversioned caller DTOs must be supported, the integrator must define an explicit validated conversion before entering the versioned A2 API; silent defaults at this boundary remain unsafe.

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

## P1 интеграционные тестовые векторы A2 → A4 / MVP (предложение, 2026-11-03)

**Новый проверяемый mismatch при чтении A4 handoff:** A4's proposed minimum E2E scenario describes abstract `A → B`. Это корректный математический тест A4, но **не является допустимым текстовым химическим уравнением A2**: `A` не является символом элемента, а `B` обозначает бор; A2 обязан отклонить `A -> B` как `PARSE_UNKNOWN_ELEMENT` и не может сертифицировать сохранение элементов в таком исходном тексте. Для полноценного A2→A4→A5 E2E необходим отдельный химически корректный исходник; A4-specific `A→B` остаётся изолированным solver benchmark.

**Предлагаемый химически корректный P1 smoke fixture:** `N2O4(g) -> 2NO2(g)`. Это *условная учебная, заведомо необратимая модель на выбранном интервале*, а не утверждение, что реальная система N₂O₄/NO₂ термодинамически необратима или что применимость закона скорости проверена. Парсер A2 должен вернуть один реагент и один продукт, фазы `GAS`, стрелку `FORWARD`, коэффициенты 1 и 2; обе проверки состава N:2 и O:4 и заряда 0 должны пройти. A2 не создаёт каталоговые IDs и не выбирает кинетику.

Отдельный слой интегратора после утверждения контракта должен:
- присвоить **различные стабильные species IDs** для N₂O₄(g) и NO₂(g), сохранив исходные `term_id` как parse-local diagnostics и occurrence phase;
- преобразовать коэффициенты в A4 signed stoichiometry **−1, +2** (A2 передаёт только положительные коэффициенты и стороны);
- передать **явно выбранные, не выведенные из стехиометрии** rate law `r = k × [N2O4]`, order 1 для N₂O₄, `k = 0.1 s^-1`, `V = 1 m³`, `n₀(N2O4)=1 mol`, `n₀(NO2)=0 mol`, постоянную T и подтверждённую модельную применимость; параметры численные/демонстрационные, не справочные A1;
- проверить для этой упрощённой модели `n_N2O4(t) = exp(-0.1t) mol`, `n_NO2(t) = 2×(1−exp(-0.1t)) mol`; elemental N-invariant `2 n_N2O4+n_NO2 = 2 mol`, O-invariant `4 n_N2O4+2 n_NO2 = 4 mol`, **в пределах объявленных численных допусков**;
- при отсутствующем k/order/units, unresolved identity/phase, ошибке charge/atom balance или несовместимом A4-host возвращать явный blocked/error status, а не запускать расчет. Источник/качество/применимость константы и форматы ошибок должны отвечать утверждённым A1/интеграторским правилам.

| A2 source fixture | Проверяемые A2-инварианты | Следующий интеграционный шаг / статус |
|---|---|---|
| `A -> B` | `PARSE_UNKNOWN_ELEMENT`, нет допустимого FormulaAST | Нельзя использовать как A2 E2E; A4-only abstract benchmark |
| `N2O4(g) -> 2NO2(g)` | parse success; `FORWARD`, `GAS`, coefficient 1/2; атом/заряд balanced; round trip | **P1 proposed positive E2E**, зависит от approved SpeciesRef, signed mapping, rate law, Godot↔.NET bridge |
| `H2 + O2 -> H2O` | parse success, исходный баланс false; предложенные коэффициенты 2/1/2 без мутации входа | UI/adapter не может запускать расчет только по успешному parse |
| `Ag+ + Cl- -> AgCl(s)` | charges +1/−1/0, product phase `SOLID`, check balance succeeds | Фаза `UNSPECIFIED` у входных ионов требует явной adapter policy; без неё не угадывать `AQUEOUS` |
| `H2(g) + I2(g) ⇌ 2HI(g)` | reversible arrow retained, balanced, phases `GAS` | K-only не является кинетическим k; A4 irreversible time-series не запускать без отдельной утверждённой модели |
| `H2 + H2 + O2 -> H2O` | сохраняются оба исходных локатора, solver агрегирует одинаковые входные члены без произвольного распределения коэффициента | Adapter должен сохранить source mapping; без утверждённой identity/aggregation policy блокировать |
| `Fe^3+ + 2Cl- -> FeCl2` | element residuals 0, charge residual +1 → balance false | Не передавать как валидную реакцию в A3/A4 |
| `H2 + O2 → H2Xx` | `PARSE_UNKNOWN_ELEMENT` и global character-index span на `Xx` | A5 должен сохранить точный источник/индексы, не переводить в UTF-8 byte offsets |

**Условия выхода из P1:** интегратор утверждает contract/adapter owner и явную обработку `UNSPECIFIED`; владелец утверждает OpenSpec; A2/A4/A5 совместно запускают тесты на одном интегрированном Godot runtime и записывают SHA+CI. До этого таблица — спецификация/hand-off, не исполняемые тесты и не утверждённый DTO. A2 не пишет A4 bridge/UI, не приписывает A1 научной достоверности демо-k и не объявляет общую готовность.

## P1 реализовано: точные source-local строки сохранения атомов/заряда (A2-EXACT-LAWS-09, 2026-11-03)

Вход — только исходная строка реакции. `ChemStoichiometryHandoff.extract_balanced_terms(source)` повторно запускает реальный `ChemEquationParser.parse_reaction()` и `check_balance()`; **не** доверяет сгенерированному извне словарю `FormulaAST`. Для ошибочной или несбалансированной реакции возвращает `ok=false` без `terms` и без `conservation_rows`.

Для успешно разобранной и точно сбалансированной реакции A2 SHALL возвращать исходные вхождения членов (с отдельными локальными `source_term_id`, Godot-character `source_span`, `element_counts`, `net_charge`, `phase`, положительным коэффициентом и `signed_stoichiometric_coefficient`) и отдельный массив `conservation_rows`:
- Каждая `ELEMENT`-строка содержит символ элемента и ненулевые точные коэффициенты по **исходным вхождениям**, отсортирована по символу элемента.
- `CHARGE`-строка присутствует всегда и содержит ненулевые знаковые заряды по исходным вхождениям; пустая строка означает подтверждённый нулевой заряд всех участников, **не** неизвестный/непроверенный заряд. Пустую строку нельзя передавать как содержательное численное ограничение A4.
- Для каждой строки `Σ_i row_coefficient_i × signed_stoichiometric_coefficient_i = 0`; здесь знак стехиометрии у реагента отрицательный, у продукта положительный. Прямая невязка `check_balance()` определяется как реагенты **минус** продукты, то есть знак ненулевой невязки противоположен.
- Повторяющиеся `H2` на одной стороне SHALL сохранить различные `source_term_id`, а не быть слиты по формульной строке. Эти ID **не** являются постоянными ссылками на вещества.

### Scenario: N2O4 → 2NO2 source-local rows
- WHEN A2 принимает `N2O4(g) -> 2NO2(g)`
- THEN точные N/O строки содержат соответственно коэффициенты `(2,1)` и `(4,2)`, отдельная CHARGE-строка пуста, а знаковая стехиометрия равна `(-1,+2)`; обе атомные суммы по знаковой стехиометрии равны нулю.

### Scenario: Реакции с зарядами и дублями
- WHEN `Ag+(aq) + Cl-(aq) -> AgCl(s)` успешно проверена
- THEN CHARGE-строка содержит `(+1,-1)`, а Ag/Cl строки учитывают обе стороны без выдумывания электронов.
- WHEN `H2 + H2 + O2 -> 2H2O` успешно проверена
- THEN H-строка содержит **два отдельных** исходных вхождения `H2`, каждое с положительным количеством 2.

### Scenario: Отсутствие данных для неверной реакции
- WHEN разбирается `H2 + O2 -> H2O`, `Na+ -> Na` или строка без стрелки
- THEN результат содержит точную ошибку парсинга/баланса и не содержит `terms` и `conservation_rows`; передавать частичную матрицу в A4 запрещено.

**Проверка:** A2-only исходный модуль `src/chemistry/a2/chem_stoichiometry_handoff.gd`, код [2951301](https://github.com/AndreyCokol/ChemSim/commit/2951301c04efdda9d947f2c81d72a36b58026db2), тесты [98cbea9](https://github.com/AndreyCokol/ChemSim/commit/98cbea9fbdaea3bbe687ea5f5fd2f5820507e9e6), exact code/test Godot 4.3 [CI #41667608709](https://github.com/AndreyCokol/ChemSim/actions/runs/41667608709) **success**. Проверка относится к локальным A2 source facts, а **не** к A1 durable refs, общему JSON payload или A4 `ConservationLaw` / Godot↔.NET E2E. Преобразование в A4 требует решения интегратора и независимой модели кинетики.

## Ограничения и риски

- Балансировка — ограниченный точный перебор, а не универсальный ILP solver; статус ограничения поиска не эквивалентен отсутствию решения.
- Минимизация суммы коэффициентов зависит от определения «различного solver-члена» и правил агрегации дублей.
- Формульная идентичность не различает изомеры и не заменяет Substance ID.
- Синтаксически корректная формула/реакция не гарантирует химическую возможность процесса.
- Парсер не проверяет термодинамическую допустимость, фазовое равновесие или кинетическую реализуемость.
- До интеграции требуется ревью точности смещений, диапазонов чисел, арифметических границ и семантики дублирующихся членов.

## Статус реализации и интеграционные критерии выхода

**OpenSpec baseline v0.1 утверждён владельцем**: `main/openspec/changes/define-chemsim-mvp/APPROVAL.md`, SHA исходного baseline `02b8b31706807279ee31a78772383e31f425f7d3`. Это разрешает A2 scoped implementation/tests, но не утверждает завершённую общую wire-схему или релиз. A1 подтвердил разграничение FormulaAST/Species ID и phase; A3/A4 предоставили consumer reviews. Общие правила идентичности и сериализации на границах системы нужно проверить отдельными адаптерами.

**Реализовано и проверено отдельно в A2:** парсер формул/реакций; atom/charge balance; bounded explicit balancing; source spans в символьных Godot String offsets; строгая fail-closed валидация `schema_version=1`, arrow, коэффициента и phase во внешних A2 Reaction DTO. Exact code/test HEAD `dd3de4b396e9a38fe0fccb0f043159ac396fadc6` passed CI [#41657267795](https://github.com/AndreyCokol/ChemSim/actions/runs/41657267795).

**Не завершено:** approved and versioned shared FormulaAST/Reaction/BalanceResult payload shape, stable SpeciesRef/ReactionRef assignment and revision ownership, phase `unspecified` mapping, canonical charge/arrow alias acceptance INT-28/29, UTF-8 byte `SourceSpan` conversion including insertion-point errors (current parser has valid zero-width character spans), namespaced ErrorEnvelope and actual integrated Godot↔.NET / A5 consumer tests. Exact A2 compatibility review: `integrator-v0.1-compatibility-review.md`. Ни один из этих пунктов не считается DONE по факту прохождения изолированного A2 CI.

Любое несовместимое изменение **общего** DTO-контракта требует интеграторского согласования и версии; A2 не создаёт устойчивые Species/Reaction IDs из formula/source offsets и не выводит K, k или kinetic orders.
