# A1 — Контракты химических данных и домена

Дата: 2026-11-02  
Статус: **предложение A1 для согласования интегратором; не утверждённый публичный DTO contract**.  
Область: только chemistry-domain, data provenance, units, licensing и hazard metadata. Реализация не выполнялась.

## 1. Результат аудита OpenSpec

Проверены:
- `openspec/config.yaml`;
- `openspec/changes/define-chemsim-mvp/proposal.md`;
- `openspec/changes/define-chemsim-mvp/design.md`;
- `openspec/changes/define-chemsim-mvp/tasks.md`;
- `openspec/changes/define-chemsim-mvp/questions.md`;
- `openspec/specs/chemistry-domain/spec.md`;
- `openspec/reviews/round-1/benchmark-matrix.md`;
- `openspec/reviews/round-1/integrated-findings.md`;
- предшествующий отчёт `agent-a1-data-domain.md`.

Фактический change ID — `define-chemsim-mvp`, а не `chemistry-domain`. Поэтому первоначальные пути `openspec/changes/chemistry-domain/*` отсутствуют; это ошибка предположения о пути, а не отсутствие proposal/design/tasks в репозитории.

### Совместимость и замечания

1. Scope MVP и правила «не выдумывать значения», сохранять неполные пользовательские записи и блокировать только зависимый расчёт согласованы.
2. Текущая spec уже требует типизированные свойства, basis для K, provenance и license gate, но не задаёт нормативные структуры полей и семантику missing/null.
3. В design перечислены общие DTO, но недостаточно определены единая структура Source/Provenance, DataQuality, Hazard completeness, ID namespace, ошибки и схема миграций.
4. Формулировка «каждое численное свойство имеет uncertainty» требует уточнения: для пользовательского ввода и некоторых exact/defined quantities допустимы явно заданные `not_reported`, `not_applicable` или `exact_by_definition`; молчаливое отсутствие запрещено.
5. Molar mass должна быть производным/проверяемым свойством от состава и версии atomic-weight dataset, а не независимым несогласованным дубликатом. Для изотопно-специфичных записей потребуется отдельная атомная масса и изотопный состав.
6. Формула, элементный состав, заряд и фаза должны ссылаться на A2 FormulaAST/Species contract. A1 не задаёт грамматику и не вычисляет состав из строки самостоятельно.
7. NIST Chemistry WebBook — SRD 69; нельзя считать, что общая федеральная открытость NIST автоматически разрешает включать SRD в распространяемый ZIP. Для SRD требуется отдельное разрешение/лицензия на распространение.
8. Benchmark matrix задаёт сценарии и необходимые данные, но не утверждает численные константы или ожидаемые значения. A1 не добавляет численных fixtures.

## 2. Предлагаемые доменные контракты

Ниже — логическая схема для обсуждения. Это не язык сериализации и не готовые классы. Все публичные записи содержат `schema_version`; единицы представлены нормализованным идентификатором единицы и размерностью, а не произвольной строкой.

### 2.1 SubstanceRef

Минимальная ссылка на вещество:

| Поле | Тип / правило |
|---|---|
| `substance_id` | Неперезаписываемый стабильный ID |
| `catalog_scope` | `builtin` или `user` |
| `schema_version` | Версия схемы ссылки |
| `revision` | Версия записи, на которую ссылается документ |

Предлагаемая форма ID: `urn:chemsim:substance:<UUID>`. Встроенные ID назначаются один раз и сохраняются между релизами; пользовательские ID создаются локально и не зависят от имени, формулы или позиции в каталоге. Не использовать формулу как primary key: формулы могут быть неоднозначны по изомерии, изотопам, гидратному/сольватному состоянию и фазе.

### 2.2 SubstanceRecord

| Поле | Обязательность | Семантика |
|---|---|---|
| `schema_version` | MUST | Версия структуры записи |
| `substance_id` | MUST | Стабильный ID |
| `record_revision` | MUST | Монотонная версия конкретной записи |
| `record_origin` | MUST | `curated_reference`, `experimental`, `calculated_estimated`, `user_defined`, `hypothetical` |
| `display_name` | MUST* | Отображаемое имя; для пользовательской записи допускается ID как временное имя |
| `formula_ast_ref` | MUST для химической сущности | Ссылка на канонический AST/Species от A2; не повторять parser logic |
| `elemental_composition` | MUST, если формула поддерживается | Элемент → целочисленное количество атомов; изотопы — отдельный ключ при поддержке |
| `formal_charge` | MUST для иона/частицы | Целое число; ноль не означает отсутствие данных |
| `phase` | MUST NOT как поле идентичности SubstanceRecord; MAY как reference/physical-form property с условиями | Фаза конкретного участника реакции задаётся в SpeciesRef/ReactionTerm по контракту A2; `unknown` блокирует только фазозависимую модель |
| `synonyms` | MAY | Список алиасов с provenance при необходимости |
| `properties` | MAY | Ноль или более PropertyRecord |
| `record_completeness` | MUST | `complete_for_identity`, `incomplete`, `invalid` |
| `provenance` | MUST | Происхождение самой записи |
| `created_at`, `updated_at` | MUST для user | UTC timestamp |
| `supersedes` | MAY | Предыдущая ревизия, если запись обновлена |

`MUST*`: встроенная запись обязана иметь устойчивое display name; пользовательская запись может сохраняться с автоматически сформированным временным названием. Наличие формулы не гарантирует структурную уникальность вещества.

**Не помещать в SubstanceRecord:** текущую массу/количество/концентрацию в эксперименте, координаты вокселя, выбранный растворитель эксперимента, температуру конкретного опыта. Это состояние эксперимента, а не идентичность вещества.

### 2.3 PropertyRecord

Каждое свойство — отдельное утверждение с собственным происхождением. Пример property key: `molar_mass`, `density`, `solubility`, `standard_enthalpy_of_formation`, `heat_capacity`, `pKa`, `rate_constant`. Список ключей должен быть реестром, а не произвольным свободным текстом для встроенных данных.

| Поле | Обязательность | Семантика |
|---|---|---|
| `property_id` | MUST | Стабильный ID утверждения |
| `property_key` | MUST | Ключ из реестра свойств |
| `value` | MUST при статусе present | Число/структурированное значение; отсутствующее значение не кодируется нулём |
| `value_status` | MUST | `present`, `not_reported`, `not_applicable`, `unknown`, `withheld` |
| `unit` | MUST для размерного числа | Канонический unit ID; безразмерные величины явно используют единицу `1` |
| `dimension` | MUST для численного значения | Нормализованная размерность; проверяется против property_key |
| `basis` | MUST, если свойство зависит от основы | Например `amount_concentration`, `molality`, `mass_fraction`, `activity`; не смешивать шкалы |
| `conditions` | MUST для условно-зависимого свойства | T, P, phase, medium/solvent, composition, pH и прочие применимые условия |
| `validity` | MUST для справочного численного свойства | Диапазоны/область условий и поведение на границе |
| `uncertainty` | MUST* | Число и тип неопределённости, доверительный уровень/метод при наличии; иначе явный код состояния |
| `significant_digits` | SHOULD | Значащие цифры исходного источника; не выводить фиктивную точность |
| `method` | SHOULD | Метод измерения, расчёта или оценки |
| `provenance` | MUST | SourceRecord/ProvenanceRef |
| `data_quality` | MUST | Качество этого конкретного утверждения |
| `notes` | MAY | Ограничения и примечания |

`MUST*`: для справочных и экспериментальных численных данных должна быть сообщена неопределённость либо явно указано `not_reported`; для пользовательского ввода — `user_did_not_specify`; для определённых по определению констант — `exact_by_definition`. Это не разрешает молча опускать uncertainty.

### 2.4 ThermoConstantRecord

Это специализированная запись для `K`, `Ka`, `Kb`, `Ksp), а не обычный PropertyRecord с произвольным числом.

| Поле | Обязательность | Семантика |
|---|---|---|
| `constant_id`, `schema_version` | MUST | ID и версия схемы |
| `constant_kind` | MUST | `K`, `Ka`, `Kb`, `Ksp` или зарегистрированный тип |
| `value` | MUST | Численное значение при указанном наборе условий |
| `basis` | MUST | `activity`, `fugacity`, `pressure`, `concentration`, `molality` или иной зарегистрированный basis |
| `standard_state` | MUST | Стандартные состояния участвующих компонентов и принятая конвенция |
| `dimensional_convention` | MUST | `dimensionless` с указанными activity/standard-state ratios либо размерная convention с явной размерностью |
| `temperature` | MUST | Значение и единица |
| `pressure` | MUST, если релевантно basis/модель | Значение и единица либо явный `not_applicable` |
| `phase_medium` | MUST | Фазы и растворитель/среда, к которым относится запись |
| `reaction_or_equilibrium_ref` | MUST | Однозначная ссылка на реакцию/равновесие A2/A3 |
| `validity` | MUST | Область применимости, включая состав/ионную силу, если применимо |
| `uncertainty` | MUST | Значение/тип или явный `not_reported` с блокирующим/предупреждающим статусом по политике fixture |
| `provenance` | MUST | Первичный источник, редакция/версия, страница/таблица/DOI |
| `data_quality` | MUST | Статус качества |
| `conversion_record` | MUST, если значение преобразовано | Исходная запись, формула/метод, входные данные и uncertainty propagation |

Нельзя автоматически считать `Kp`, `Kc` и activity-based `K` взаимозаменяемыми. Преобразование допустимо только если явно доступны стандартные состояния, размерности, условия и модельные предпосылки. Одно значение K относится к определённой температуре; K(T) требует отдельной обоснованной записи/модели.

### 2.5 Provenance, SourceRecord и DataQuality

Единая структура provenance:

- `source_id`: стабильный ID источника/поставщика;
- `source_title`, `publisher`, `authors`: библиографические сведения;
- `source_uri`: устойчивый URL/DOI;
- `source_version`: выпуск, версия, дата набора или редакция;
- `retrieved_at`: дата получения;
- `locator`: конкретная таблица, раздел, страница, запись или dataset row;
- `assertion_method`: measured / evaluated / computed / estimated / user-entered;
- `license_id`, `license_text_uri`, `license_review_status`;
- `attribution_text`: требуемая атрибуция;
- `redistribution_scope`: `allowed`, `allowed_with_conditions`, `permission_required`, `not_allowed`, `unknown`;
- `reviewed_by`, `reviewed_at`: проверка включения в bundle.

DataQuality — не вероятность и не одна шкала «точности». Предлагаемые поля:
- `origin_class`: curated_reference / experimental / calculated_estimated / user_defined / hypothetical / unknown;
- `evidence_status`: verified / partially_verified / unverified / conflicting / unknown;
- `uncertainty_status`: reported / not_reported / user_unspecified / exact_by_definition / not_applicable;
- `applicability_status`: in_range / boundary / out_of_range / unknown;
- `license_status`: approved / conditional / permission_required / prohibited / unknown;
- `completeness`: complete / partial / missing_required_fields.

Нельзя сводить эти поля к одному числу или использовать `curated` как синоним «экспериментально измерено».

### 2.6 HazardRecord

Hazard data хранятся как утверждения, а не булевый флаг `is_hazardous`.

| Поле | Обязательность | Семантика |
|---|---|---|
| `hazard_record_id`, `schema_version` | MUST | ID и версия |
| `substance_id` | MUST | Вещество/идентичность, к которой относится запись |
| `jurisdiction` | MUST | Например EU CLP, US OSHA HazCom; нельзя смешивать юрисдикции |
| `classification_system` | MUST | Название и версия нормативной системы |
| `hazard_classes` | MAY | Класс/категория, только если источник это сообщает |
| `h_statements`, `p_statements` | MAY | Идентификатор и текст/ссылка, без самодельной классификации |
| `signal_word`, `pictograms` | MAY | Только подтверждённые данные |
| `source` | MUST | Provenance конкретного hazard assertion |
| `effective_date`, `retrieved_at` | MUST | Даты актуальности/получения |
| `completeness` | MUST | См. ниже |
| `review_status` | MUST | verified / partially_verified / unverified / conflicting |
| `limitations` | MAY | Например: нет данных по смеси, форме/концентрации, юрисдикции |

Hazard completeness enum:
- `not_assessed`: проверка не проводилась;
- `no_data_found`: поиск в указанном источнике/области выполнен, записи не найдено;
- `partial`: есть отдельные утверждения, но покрытие неполное;
- `complete_for_scope`: проверен определённый scope (вещество, форма, юрисдикция, дата), не «абсолютно полные сведения»;
- `conflicting`: источники расходятся;
- `not_applicable`: только при документированном обосновании, не для пустой записи.

UI-строки:
- not_assessed — «Опасности не проверены. Отсутствие сведений не означает безопасность».
- no_data_found — «В выбранных источниках сведения не найдены. Вещество не следует считать безопасным».
- partial — «Данные об опасности неполные; проверьте SDS и актуальные требования».
- complete_for_scope — «Данные проверены для указанной юрисдикции и версии источника; это не заменяет SDS и инструкции».
- conflicting — «Источники содержат противоречивые сведения; требуется проверка».
- not_applicable — «Не применимо в указанном контексте» с раскрываемым обоснованием.

Никакой из этих статусов не должен автоматически генерировать GHS-классификацию. Смеси, концентрации, гидраты и разные формы вещества требуют проверки scope отдельно.

## 3. Разделение идентичности и требований расчётных моделей

| Данные | Идентификация записи | Требуется только соответствующей модели |
|---|---|---|
| ID, имя/алиасы | Да | Нет |
| FormulaAST / элементный состав / заряд | Да, для поддерживаемой химической частицы | Да для баланса/реакций |
| Фаза | Не входит в идентичность SubstanceRecord; хранится в SpeciesRef/ReactionTerm как контекст частицы | Обязательна для фазово-зависимой модели |
| Молярная масса | Нет, это производное свойство | Для g ↔ mol; требует состава и atomic-weight dataset либо проверенного значения |
| Плотность | Нет | Для преобразования объём ↔ масса/количество при соответствующих условиях |
| Объём системы | Нет | Для mol ↔ mol/L и соответствующего материального баланса |
| T и P | Нет | Для моделей/свойств, зависящих от температуры/давления; P обязательно для соответствующих газовых расчётов |
| Растворимость | Нет | Для растворения/осаждения и проверки насыщения |
| Activity coefficient / activity model | Нет | Для модели раствора, которая использует активности |
| Ka/Kb/Ksp | Нет | Только соответствующий equilibrium solve; обязательны basis и стандартное состояние |
| Kp/Kc | Нет | Только совместимая газовая/концентрационная equilibrium formulation |
| k, reaction orders, Ea | Нет | Только kinetic solver; A4 контракт, не заменять K |
| HazardRecord | Нет | Энциклопедия и предупреждения; не требуется для математического solver, но обязателен UX-safe status |

Пользовательская запись может существовать без молярной массы, растворимости, K или hazard data. Требования проверяются по выбранной модели, а не по универсальному «complete substance» флагу.

## 4. Матрица моделей и обязательных данных

| Модель / операция | Обязательные данные | Допустимый fallback | Блокирующие пробелы |
|---|---|---|---|
| Отображение/поиск каталога | ID, имя или ID как placeholder | Нет | Некорректный/дублирующий ID |
| Парсинг и баланс | FormulaAST, состав элементов, заряд, коэффициент из A2 | Нет | Неизвестная/неподдерживаемая формула или заряд |
| g ↔ mol | Масса, молярная масса, единицы | Вычислить M из composition + approved atomic weights | Нет M/изотопной спецификации |
| mol ↔ mol/L | Количество вещества, объём раствора | Нет | Не задан/невалиден объём |
| g/L ↔ mol/L | Массовая концентрация, M | Нет | Нет M или несогласованные basis |
| Идеальный газ PV=nRT | Количество вещества и любые две независимые state variables из P,V,T; корректные units | Только идеальная газовая модель, явно маркированная | Недостаточно state variables, отрицательные/нулевые недопустимые значения, невалидная фаза |
| Закон Дальтона | Мольные доли/количества и общее давление | Нет | Нет общего давления/состава |
| Разбавленный идеальный раствор | Объём, totals/concentrations, стехиометрия, T; явно выбранное идеальное приближение | gamma=1 только как явная модель assumption | Неподходящая среда/концентрация вне валидированного домена |
| Модель активностей | Всё для выбранной модели + параметризация/параметры коэффициентов активности и применимость | Нет | Недостаточно параметров или выход за диапазон |
| pH сильной кислоты/основания | Концентрации/количества, объём, стехиометрия, модель допущений | Идеальная разбавленная модель, явно подписанная | Нет объёма/концентрации или невалидные данные |
| pH слабой кислоты/основания | Предыдущие данные + Ka/Kb с T, basis, standard state, medium, source, uncertainty | Нет | Нет применимой Ka/Kb или несовместимый basis |
| Ksp/осаждение | Растворённые species, баланс totals, T, Ksp basis/standard state, medium/activity assumption | Явное ideal-dilute approximation | Нет Ksp или несовместимость basis/medium |
| Равновесие газа | Reaction, T, pressure/state, Kp/K-compatible basis, standard pressure/state, source | Идеальный газ, если явно принят | Нет K или несовместимые standard states |
| Временная кинетика | От A4: rate law, orders, k и units, начальное состояние; reverse kinetics если reversible | Нет автоматического вывода из K | Нет k/orders/rate law |
| Энциклопедия hazard | HazardRecord или явный completeness status | «Не проверены» | Нельзя показывать отсутствие карточки как «не опасно» |

Точные пороги разбавленности, концентрационные границы и допустимые диапазоны конкретных моделей должны задаваться A3 по проверяемым источникам/валидации; A1 не назначает их по памяти.

## 5. Allowlist-кандидаты источников и лицензирование

**Статусы ниже — результат desk research на дату отчёта, не юридическое заключение.** «Кандидат» не означает автоматическое разрешение на включение всего набора. Встроенный каталог утверждается только на уровне конкретного поля/источника/версии/лицензии.

| Источник | Для чего использовать | Лицензия / повторное использование | Решение A1 |
|---|---|---|---|
| IUPAC Gold Book | Термины activity, equilibrium constant, standard state и единая терминология | Отдельные термины указаны как CC BY-SA 4.0; для коммерческого использования Gold Book просит обращаться в IUPAC. Возможен share-alike/атрибуционный эффект | **Только терминологический reference**. Не копировать большие тексты/определения в bundle до проверки коммерческих условий и совместимости CC BY-SA |
| CIAAW Standard Atomic Weights | Атомные веса и интервалы/неопределённости для вычисления молярных масс | CIAAW/IUPAC разрешает republication при полной атрибуции и условиях; коммерческое использование требует обращения к секретариату | **Conditional**: получить письменное разрешение/разъяснение для распространяемого приложения, особенно коммерческого; сохранять edition/year и interval uncertainties |
| NIST Chemistry WebBook SRD 69 | Термохимия, Cp, энтальпии, термодинамика реакций и отдельные физические свойства в заявленном покрытии | SRD защищены по Standard Reference Data Act; воспроизведение/хранение/распространение требует предварительного разрешения; для дистрибуции нужен отдельный distributor agreement | **Не включать данные в redistributable bundle** без отдельного соглашения NIST. Можно использовать как исследовательский указатель и цитировать источники |
| PubChem | Идентификаторы, формулы, синонимы, структурные/физические аннотации и ссылки на первоисточники | PubChem агрегирует сотни источников; условия задаются конкретным contributor/field. Наличие данных в PubChem само по себе не даёт общей лицензии | **Не whitelist PubChem целиком**. Импортировать только записи, у которых установлен первичный источник и явно разрешено повторное распространение |
| ECHA CHEM / ECHA website | Hazard classifications, regulatory information, selected substance facts | Материалы ECHA в общем случае можно использовать с атрибуцией, но исключены third-party IP и whole/substantial database extraction; CAS information отдельно защищены; систематическое извлечение ограничено | **Только точечные записи** после проверки авторства и third-party rights; не зеркалировать базу/массовые выборки. Указывать юрисдикцию/дату |
| EUR-Lex / EU legislation | Текст CLP и нормативные H/P statements/классификационные правила | Для editorial content EU действует CC BY 4.0, если не указано иначе; отдельные элементы могут иметь third-party rights | **Кандидат** для текста законодательства/нормативных кодов с атрибуцией; это не готовая база классификаций веществ |
| Первичные публикации (журналы/статьи) | Ka, Kb, Ksp, equilibrium constants, kinetic/thermo values | Лицензия определяется конкретной статьёй/издателем; open access не означает одинаковые права для всех таблиц и supplementary data | **Только article-by-article**. Сохранять DOI, версию, таблицу/страницу, лицензию, авторов, uncertainty и условия |
| User-provided data | Свойства пользовательских/гипотетических веществ | Пользователь подтверждает, что имеет право вводить данные; приложение не превращает их в curated data | Хранить как user_defined/hypothetical; не переносить в общий bundle без отдельного согласия и проверки |

### Правило включения в офлайн bundle

`redistribution_scope=allowed` допускается только если подтверждены: право хранить локальную копию, право распространять её в составе приложения, коммерческое/некоммерческое назначение проекта, атрибуция, share-alike/обязательства производных баз, ограничения на bulk extraction и third-party rights.

Если любое условие не выяснено — `unknown` или `permission_required`, и запись исключается из redistributable bundle. Отдельно хранить лицензию на программное обеспечение и лицензию на данные.

## 6. Позитивная и негативная матрица тестов

### 6.1 Размерности и конверсии

| ID | Вход / условие | Ожидаемый результат |
|---|---|---|
| DIM-01 | g + M(g/mol) → mol | Успех; размерность mol |
| DIM-02 | mol + V(L) → mol/L | Успех; размерность amount/volume |
| DIM-03 | g/L + M(g/mol) → mol/L | Успех только при согласованных величинах |
| DIM-04 | mol/L преобразуется в mol/kg без плотности/состава | Ошибка несовместимого basis; не выполнять |
| DIM-05 | g → mol без M | Блокировать конверсию, но сохранить запись |
| DIM-06 | mol → mol/L без объёма | Блокировать конверсию |
| DIM-07 | kPa и Pa | Корректная конверсия масштаба |
| DIM-08 | °C и K | Корректная аффинная конверсия с offset; не трактовать как простой коэффициент масштаба |
| DIM-09 | размерная K и безразмерная activity-based K | Запретить прямое сравнение/подстановку |
| DIM-10 | unit не соответствует property_key (например density в mol) | Ошибка dimension mismatch |
| DIM-11 | нулевой/отрицательный объём или некорректная физическая область | Domain validation error |
| DIM-12 | состав с изотопной спецификацией и natural atomic weights | Запросить подходящий isotopic mass data; не подменять обычным average |

### 6.2 Provenance, качество и лицензии

| ID | Вход / условие | Ожидаемый результат |
|---|---|---|
| PROV-01 | Curated property с source/version/locator/license | Импорт допустим после license review |
| PROV-02 | Source отсутствует у встроенного числа | Отклонить импорт |
| PROV-03 | License unknown | Не включать в redistributable bundle |
| PROV-04 | PubChem field без первичного contributor | Не считать лицензированным по умолчанию |
| PROV-05 | Source version обновлена | Создать новую revision; старый experiment replay остаётся привязан к старой версии |
| PROV-06 | Estimated/calculated property | Явно пометить method и origin; не повысить до experimental |
| PROV-07 | Пользователь ввёл число без источника | Сохранить как user_defined с user provenance и uncertainty_status=user_unspecified |
| PROV-08 | Источник имеет диапазон условий, опыт вне диапазона | applicability=out_of_range; соответствующий расчёт блокируется/предупреждается по политике модели |
| PROV-09 | Две конфликтующие величины из разных источников | Хранить отдельные assertions; не усреднять молча |
| PROV-10 | License changes between releases | Новый license review; заблокировать новый bundle до повторного допуска |

### 6.3 Hazard completeness

| ID | Вход / условие | Ожидаемый результат |
|---|---|---|
| HAZ-01 | Нет HazardRecord | UI «Опасности не проверены…» |
| HAZ-02 | Поиск проведён, данных не найдено | `no_data_found`, не «не опасно» |
| HAZ-03 | Есть классификация только для одной юрисдикции | `partial` для глобального scope; UI показывает юрисдикцию |
| HAZ-04 | Полные данные только для конкретной формы/концентрации | `complete_for_scope` только для этого scope |
| HAZ-05 | Источники противоречат | `conflicting`; не выбирать одну классификацию молча |
| HAZ-06 | Отсутствует H/P statement в исходнике | Не генерировать его автоматически |
| HAZ-07 | Источник устарел/отозван | Сохранить историю, пометить current status stale/needs_review |
| HAZ-08 | Hazard data для parent substance применяются к раствору/смеси | Не переносить автоматически без применимого правила классификации |

## 7. Ошибки домена (предложение для интегратора)

Стабильные машинные коды, сообщения локализуются по `message_key`; текст ошибки не является API contract.

| Code | Значение |
|---|---|
| `CHEM_SUBSTANCE_NOT_FOUND` | Ссылка на вещество не найдена |
| `CHEM_SUBSTANCE_ID_CONFLICT` | ID уже занят другой записью |
| `CHEM_FORMULA_UNSUPPORTED` | Формула вне грамматики MVP (A2 подтверждает) |
| `CHEM_FORMULA_INVALID` | Формула синтаксически/структурно некорректна (A2 подтверждает) |
| `CHEM_CHARGE_UNKNOWN` | Заряд неизвестен там, где он обязателен |
| `CHEM_PHASE_UNKNOWN` | Фаза неизвестна там, где она обязательна |
| `CHEM_PROPERTY_MISSING` | Обязательное свойство отсутствует |
| `CHEM_PROPERTY_VALUE_UNKNOWN` | Свойство известно как неизвестное/not_reported |
| `CHEM_UNIT_UNKNOWN` | Единица не распознана |
| `CHEM_DIMENSION_MISMATCH` | Единица имеет несовместимую размерность |
| `CHEM_BASIS_MISMATCH` | Несовместимая шкала/basis (например molarity vs molality) |
| `CHEM_CONDITION_OUT_OF_RANGE` | Условия вне valid range |
| `CHEM_STANDARD_STATE_MISMATCH` | Несовместимое стандартное состояние |
| `CHEM_PROVENANCE_MISSING` | Нет происхождения встроенного значения |
| `CHEM_LICENSE_NOT_APPROVED` | Лицензия не разрешает/не подтверждает bundle inclusion |
| `CHEM_HAZARD_DATA_INCOMPLETE` | Hazard record отсутствует/неполон |
| `CHEM_DATA_CONFLICT` | Источники содержат конфликтующие утверждения |
| `CHEM_SCHEMA_VERSION_UNSUPPORTED` | Версия схемы не поддерживается |
| `CHEM_MIGRATION_REQUIRED` | Нужна миграция записи/документа |

Error envelope для согласования: `code`, `severity`, `message_key`, `context`, `missing_fields[]`, `source_refs[]`, `recoverability`. A1 предлагает коды, но публичный enum утверждает интегратор совместно с A2–A5.

## 8. Версионирование и миграции

Обязательные versioned structures:
- SubstanceRecord, SubstanceRef;
- PropertyRecord и реестр property keys/units;
- ThermoConstantRecord и справочник basis/standard states;
- SourceRecord/Provenance;
- HazardRecord и классификационные enum;
- локальный каталог manifest;
- user catalog document;
- Error envelope.

Правила:
1. `schema_version` — версия структуры, не версия конкретных данных; `record_revision` — ревизия записи; `dataset_version` — версия набора; эти понятия не смешивать.
2. Миграция должна быть версионированной, детерминированной, идемпотентной и сохранять исходную provenance.
3. Неизвестное поле будущей версии нельзя молча удалять при сохранении.
4. Неизвестная обязательная версия — read-only/error, не best-effort parse.
5. Перевод отсутствующего поля в `null` запрещён без явной миграционной семантики. Различать absent, null, unknown, not_reported и zero.
6. Обновление источника/значения создаёт новую запись или ревизию; experiment replay фиксирует точные ID/версии данных.
7. Для изменения unit, basis, formula AST semantics, uncertainty representation, hazard jurisdiction/classification, license metadata требуется migration note и тест на обратную совместимость.

## 9. Межагентные зависимости и вопросы интегратору

| Контрагент | Предложение A1 | Требуется согласование |
|---|---|---|
| A2 | FormulaAST/Species является источником истины для composition, charge, phase; SubstanceRecord хранит ссылку/снимок версии | ID namespace, AST version, formula canonicalization, isotope support |
| A3 | ThermoConstantRecord передаётся с basis/standard state/T/medium; A3 объявляет model-specific required properties | Activity basis, molality/molarity conversions, exact valid range and equilibrium DTO |
| A4 | k/Ea/orders остаются kinetic properties; units зависят от rate-law orders | Реестр единиц k для разных rate laws, uncertainty и applicability |
| A5 | Энциклопедия показывает происхождение, quality vector и hazard completeness; offline DB хранит source/license manifest | Тексты статусов, структура bundle, локальное хранилище/миграции |
| Интегратор | Единый error envelope, schema_version policy, DataQuality и unit registry | Утвердить только после cross-agent review; A1 не объявляет DTO публичными единолично |

### Блокеры

- Получить разрешение/лицензию для включения CIAAW atomic-weight dataset в распространяемый bundle (особенно при коммерческом распространении).
- Получить разрешение NIST на включение SRD 69 в bundle либо выбрать альтернативные лицензированные первичные наборы.
- Сформировать фактический allowlist property-level, а не брендов источников.
- Определить правовой режим распространения ChemSim (коммерческий/некоммерческий) — влияет на CIAAW, IUPAC и часть издательских лицензий.
- A2 должен подтвердить формальную семантику SpeciesRef/FormulaAST; A3 — equilibrium basis; A4 — кинетические units; интегратор — общий versioning/error envelope.

## 10. Что не входит в работу A1

A1 не реализует парсер/балансировщик, equilibrium/kinetics solver, термодинамические расчёты, UI, сетевой импорт или упаковку. Не добавлены численные константы для семи benchmark-сценариев. Данный документ не является юридическим заключением о лицензиях.

## 11. Внешние источники, проверенные в этом раунде

- IUPAC Gold Book — usage license and caveat about currency: https://goldbook.iupac.org/ (CC BY-SA 4.0 for individual terms; commercial use requires contacting IUPAC).
- CIAAW — atomic weights: https://ciaaw.org/atomic-weights.htm ; copyright/reuse: https://www.ciaaw.org/impressum.htm .
- NIST — Chemistry WebBook SRD 69: https://webbook.nist.gov/chemistry/ ; SRD copyright and licensing: https://www.nist.gov/open/copyright-fair-use-and-licensing-statements-srd-data-software-and-technical-series-publications ; SRD terms: https://shop.nist.gov/ccrz__CCPage?pageKey=SRDTC .
- PubChem — data sources and field-level provenance/licensing: https://pubchem.ncbi.nlm.nih.gov/docs/data-sources ; downloads and licensing caveats: https://pubchem.ncbi.nlm.nih.gov/docs/downloads .
- ECHA — legal notice, third-party rights and database extraction limits: https://echa.europa.eu/legal-notice .
- EUR-Lex / Publications Office — EU reuse policy: https://op.europa.eu/en/web/about-us/legal-notices/publications-office-of-the-european-union-copyright .

Источники проверены 2026-11-02. Для включения конкретных значений в релиз нужно повторно проверить актуальную лицензию и конкретный dataset release.


## 12. Раунд 2 — межагентная сверка и уточнения (2026-11-02)

### 12.1 A1 ↔ A2: Substance и Species нельзя сливать

A2 фиксирует, что фаза не является частью формулы и должна храниться отдельно. Это совместимо с A1, если развести три уровня:

1. **SubstanceRecord** — каталоговая сущность с устойчивым ID, именем, FormulaAST/структурной идентичностью и набором утверждений-свойств.
2. **SpeciesRef** — участник химической реакции/равновесия: ссылка на SubstanceRef/FormulaAST (состав и net charge принадлежат FormulaAST по контракту A2) плюс явно заданная phase и контекст участия. Фаза относится к конкретному species occurrence/model context, а не меняет строковую формулу.
3. **ExperimentComponent** — экземпляр вещества в эксперименте с количеством, массой/концентрацией, объёмом/состоянием и ссылкой на SpeciesRef; не является записью каталога.

Следствие: поле `phase` не должно использоваться как часть primary key SubstanceRecord. В SubstanceRecord можно хранить reference phase/physical form как свойство с условиями, но A2 ReactionTerm должен ссылаться на SpeciesRef, где фаза задана явно. Это предотвращает коллизию «одна формула — разные фазы» и не превращает фазу в часть химической формулы.

A2 владеет грамматикой FormulaAST, токенизацией, canonicalization и ReactionTerm. A1 хранит ссылку на AST/version и не дублирует разбор. Требует совместного решения: является ли SpeciesRef полноценной сущностью с собственным ID или детерминированной составной ссылкой `(substance_id, formula_ast_version, charge, phase)`. Рекомендация A1: стабильный Species ID для сохранения экспериментов и явная revision/version ссылки на FormulaAST.

### 12.2 A1 ↔ A3: basis равновесных констант

Сверка с A3 подтверждает:
- термодинамическая equilibrium constant формулируется через activities относительно standard states;
- `Kp`, `Kc`, activity-based K и эмпирические концентрационные константы не взаимозаменяемы;
- activity coefficient/model и область применимости должны входить в контекст расчёта, а не выводиться из одной константы;
- pH связан с активностью H+, а `-log10[H+]` допустим только как явно обозначенное идеальное приближение;
- K(T) нельзя экстраполировать из одной температуры без применимой термодинамической зависимости/данных.

Уточнение к схеме: `basis` сам по себе недостаточен. Для activity-based K хранить по каждому участвующему компоненту ссылку на стандартное состояние и конвенцию activity; для концентрационной константы — единицы и конкретную концентрационную шкалу. Для gas equilibrium MVP — ideal-gas partial-pressure approximation, но не записывать fugacity coefficient как будто он известен. Параметры модели активности принадлежат A3; A1 предоставляет типизированные исходные данные и применимость.

Открытый вопрос A3: какие именно equilibrium basis enum и standard-state DTO A3 готов принимать в MVP? До ответа не фиксировать enum как публичный.

### 12.3 A1 ↔ A4: кинетические свойства и размерности

A4 подтверждает, что K не задаёт временной масштаб, а k, orders, Ea и reference temperature принадлежат kinetic model. A1 должен предоставлять PropertyRecord для исходных данных, но не определять универсальный unit для k.

Для rate law вида (r = k \, \prod_i c_i^{\alpha_i}), если r выражена как концентрация/время, размерность k зависит от суммарного порядка (n=\sum_i\alpha_i): ([k]=[C]^{1-n}[t]^{-1}). Для rate law на основе amount/time, surface rate или иной формы размерность будет другой. Поэтому PropertyRecord для k обязательно должен ссылаться на конкретный rate-law definition/kinetic model ID и basis скорости. Нельзя принимать `s^-1` как универсальную единицу k.

Для Arrhenius-параметров:
- Ea — энергия на количество вещества (обычно energy/mol), с явной единицей;
- reference temperature и reference k должны быть записаны;
- R берётся в согласованной энергетической единице;
- validity interval и provenance относятся к конкретной kinetic parameter set.

Рекомендация: A4 владеет KineticParameterSet DTO и rate-law schema; A1 предоставляет общий unit registry, provenance и quality envelope. Не переносить kinetic orders в SubstanceRecord.

### 12.4 A1 ↔ A5: DataQuality не равен ReliabilityVector

A5 предлагает статус результата из data_quality, model_validity, numerical_status, completeness и warnings. A1 предлагает DataQuality для отдельного утверждения о данных. Это разные уровни:
- PropertyRecord.data_quality описывает происхождение/проверенность/неопределённость/применимость/лицензию конкретного утверждения.
- SimulationResult.ReliabilityVector.data_quality — агрегированная оценка использованных данных, сформированная интегратором из конкретных PropertyRecord и их provenance; она не заменяет исходные записи.
- Hazard completeness — отдельный статус покрытия hazard evidence, не показатель качества расчётных свойств и не probability.

A5 должен отображать причины и source/version, а не вычислять единый «процент достоверности». Отсутствие HazardRecord визуально отличается от `no_data_found`.

### 12.5 Уточнение источников по актуальным публичным страницам

Повторно проверены публичные страницы источников. Это desk research, не юридическое заключение:

| Источник | Уточнение после повторной проверки | Решение |
|---|---|---|
| IUPAC Gold Book | Официальная страница указывает CC BY-SA 4.0 для individual terms и просит обращаться в IUPAC для commercial use; также предупреждает, что часть определений могла устареть. <https://www.dev.goldbook.iupac.org/> | Использовать как терминологический указатель; перед копированием определений/массовым включением проверить share-alike и коммерческие условия |
| CIAAW | Официальный impressum разрешает republication/reproduction/storage/dissemination при видимой полной атрибуции и ©/годе; commercial use — через CIAAW Secretariat. <https://ciaaw.org/impressum.htm> | Для коммерческого ChemSim получить согласование; сохранять edition/year, диапазоны/неопределённость и атрибуцию |
| PubChem | Официальные страницы подтверждают сотни contributors, field-level/source provenance и различия лицензий; в текущем источниковом списке 891 из 1,138 sources имеют unspecified license. <https://pubchem.ncbi.nlm.nih.gov/docs/downloads> <https://pubchem.ncbi.nlm.nih.gov/docs/data-sources> | Не считать PubChem blanket-licensed; только source-specific imports с проверенной лицензией |
| ECHA | Legal notice допускает повторное использование части материалов с атрибуцией, но исключает whole/substantial database extraction и материалы третьих лиц; отдельно упоминается CAS Information. <https://echa.europa.eu/legal-notice> | Точечное использование только после проверки конкретного материала и прав третьих лиц; не зеркалировать существенную часть базы |
| NIST SRD 69 | Ранее отмеченное ограничение остаётся блокером для bundle: нельзя делать вывод о праве на распространение SRD из общей доступности сайта. <https://www.nist.gov/open/copyright-fair-use-and-licensing-statements-srd-data-software-and-technical-series-publications> | Не включать в redistributable bundle до получения применимого разрешения/соглашения |

### 12.6 Список вопросов для интегратора (не закрывать предположениями)

1. Утвердить разделение SubstanceRef / SpeciesRef / ExperimentComponent и владельца canonical Species ID.
2. Согласовать общий UnitId registry и семантику dimension/basis; решить, нужен ли UCUM-compatible identifier либо собственный закрытый registry.
3. Утвердить representation uncertainty: standard uncertainty, expanded uncertainty, interval/range, confidence level, unknown/not reported/exact-by-definition.
4. Утвердить условия допустимого использования user-provided values в benchmark/replay и правила наследования quality status в SimulationResult.
5. Согласовать scope лицензий для релиза: коммерческое или некоммерческое распространение, отдельные bundled datasets и механизм attribution manifest.
6. Получить от A3 список equilibrium basis/standard-state fields и от A4 KineticParameterSet/rate-law unit requirements.
7. Утвердить единый DomainError registry; коды A1 остаются предложением, не публичным API.

### 12.7 Новые тесты на границах DTO

| ID | Случай | Ожидаемый результат |
|---|---|---|
| DTO-01 | Одна формула, два SpeciesRef с разными фазами | Разные species context; FormulaAST остаётся одинаковым |
| DTO-02 | Один SubstanceRecord используется в двух экспериментах | Независимые ExperimentComponent amounts/state |
| DTO-03 | K(activity) подставляется в Kc model без преобразования | CHEM_BASIS_MISMATCH |
| DTO-04 | k с единицей s^-1, но rate law второго порядка | Reject dimension mismatch, если unit не соответствует declared rate law |
| DTO-05 | PropertyRecord license unknown | Может быть сохранён в исследовательской/пользовательской среде, но исключён из release bundle |
| DTO-06 | DataQuality=verified, но applicability=out_of_range | Расчёт блокируется; нельзя усреднять статусы в «verified» |
| DTO-07 | HazardRecord complete_for_scope для EU CLP, запрашивается другая юрисдикция | Для новой юрисдикции статус остаётся not_assessed/partial |
| DTO-08 | Изменился только display_name | Новая revision или metadata revision; substance_id остаётся стабильным |
| DTO-09 | FormulaAST semantics version changed | Явная migration/compatibility mapping; не менять прошлый experiment replay |
| DTO-10 | Unknown future field/schema version round-trip | Не удалять неизвестные поля и не выполнять destructive rewrite |


### 12.8 Исправление внутренней несогласованности схемы A1

При повторной проверке обнаружено, что исходная таблица SubstanceRecord (раздел 2.2) и матрица моделей (раздел 3) всё ещё называли фазу идентификационным атрибутом SubstanceRecord. Это противоречило принятому в разделе 12.1 разделению SubstanceRecord и SpeciesRef. Исправлено в этом документе:

- фаза не является частью primary identity SubstanceRecord;
- фазовый контекст задаётся в SpeciesRef/ReactionTerm по контракту A2;
- SubstanceRecord может содержать только справочное утверждение о reference physical form/phase, если оно имеет собственные условия и provenance;
- FormulaAST хранит состав и net charge по грамматике A2; SpeciesRef ссылается на эту формулу и добавляет фазу и контекст участия в конкретной реакции/модели;
- разные заряды означают разные химические частицы/идентичности, а не значение phase.

Это уточнение устраняет конфликт между исходной схемой и результатом cross-agent review. Оно не утверждает окончательный публичный DTO: точный граф ссылок и стабильность Species ID требуют решения интегратора с A2.
