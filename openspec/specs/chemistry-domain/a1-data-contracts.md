# A1 Addendum — контракты химических данных и критерии применимости

> Статус: PROPOSAL / FOR INTEGRATION REVIEW. Документ уточняет только область Agent A1.
> Не является утверждением публичных DTO, Unit Registry или OpenSpec baseline.
> До явного утверждения baseline владельцем реализация не начинается.

## 1. Принципы модели данных

1. Идентичность сущности, отдельное измеренное/рассчитанное свойство и состояние вещества в эксперименте — разные уровни данных.
2. Неизвестное значение, отсутствующее значение, неприменимое значение и нулевое значение семантически различны.
3. Качество/происхождение данных не равно пригодности для конкретной расчётной модели.
4. Пригодность проверяется для конкретной пары «свойство — модель — условия», а не одним глобальным флагом вещества.
5. Численное значение без единицы/размерности и происхождения не является готовым справочным параметром.
6. Запись пользовательского или гипотетического вещества может быть сохранена неполной; это не означает, что она пригодна для расчёта.

## 2. Предлагаемое разделение логических записей

Имена и поля ниже — логическая спецификация A1, а не окончательные имена/формы межагентных DTO.

### 2.1 SubstanceRecord

Назначение: стабильная каталоговая идентичность химической сущности.

Минимальные логические атрибуты:
- `substance_id`: стабильный ID записи, не выводимый автоматически из формулы;
- `display_name`: отображаемое имя, если задано;
- `canonical_formula`: формула в пределах грамматики MVP;
- `composition`: элементный состав, согласованный с формулой;
- `charge`: заряд;
- `record_status`: reference / user_defined / hypothetical / unknown (точный enum согласовать);
- `schema_version`: версия схемы записи после согласования общей стратегии версионирования.

Фаза, количество, концентрация, координаты и экспериментальные условия не должны становиться свойствами каталоговой идентичности SubstanceRecord. Фазовый контекст конкретного участника реакции относится к Species/ReactionTerm boundary A2. Экспериментальное количество и состояние относятся к модели эксперимента A4/A5.

Формула не является универсальным уникальным ключом вещества. Один и тот же состав/формула не должен приводить к автоматическому слиянию разных каталоговых записей. Политика изомерии и расширенной структурной идентичности остаётся вне грамматики MVP и требует отдельного решения.

### 2.2 PropertyRecord

Назначение: одно утверждение об одном свойстве, с собственным происхождением и областью применимости.

Обязательные логические группы:
- идентификация: `property_id`, `property_kind`, ссылка на субъект/вещество;
- значение: `value`, `unit`, `dimension`;
- физико-химическое основание: `basis` (если применимо), `phase`, `medium_or_solvent` (если применимо);
- применимость: `temperature_range`, `pressure_range`, иные существенные условия;
- качество: `quality_status`, `uncertainty` или явное указание, что неопределённость не сообщена;
- метод: экспериментальный/расчётный метод или unknown;
- provenance: `source_id`, `source_version_or_date`, `retrieved_at`, идентификатор исходного набора/поля и ссылка на лицензионное свидетельство;
- статус значения: present / unknown / not_reported / not_applicable (предлагаемые различимые состояния; точное кодирование согласовать).

Нельзя использовать ноль как замену отсутствующему или неизвестному значению. Нельзя считать отсутствие uncertainty доказательством нулевой неопределённости. Значащие цифры источника должны сохраняться либо преобразовываться без создания ложной точности.

### 2.3 SourceRecord и provenance

Источник должен быть отдельной логической записью, чтобы не дублировать его метаданные в каждом свойстве. Для источника фиксируются:
- устойчивый идентификатор и название поставщика/публикации;
- URL или библиографическая ссылка;
- версия, дата выпуска или дата доступа, если версия не публикуется;
- дата извлечения данных;
- исходный dataset/record/field identifier, если поставщик его предоставляет;
- лицензия и версия/дата условий;
- разрешённые действия: локальное использование, модификация, распространение, атрибуция и иные применимые ограничения;
- статус проверки лицензии и ссылка/заметка на подтверждающее основание.

Provenance должен позволять проследить конкретное значение до конкретного источника и поля. Одного указания «PubChem», «NIST» или домена сайта недостаточно, если агрегатор ссылается на стороннего поставщика.

## 3. Разделение статуса происхождения, качества и применимости

Не объединять следующие независимые измерения в один enum:

### 3.1 Происхождение/тип записи
- curated_reference — вручную проверенная/курируемая справочная запись;
- experimental — экспериментально полученное значение;
- calculated — рассчитанное значение с описанным методом;
- estimated — оценочное значение;
- user_defined — введено пользователем;
- hypothetical — относится к гипотетической сущности/сценарию;
- unknown — происхождение неизвестно.

Эти метки описывают происхождение, а не автоматически уровень доверия.

### 3.2 Качество отдельного свойства
Предлагаемые категории для интеграционного обсуждения:
- verified — происхождение, единицы и условия проверены по допустимому источнику;
- reviewed — проверено человеком/процедурой, но остаются оговорённые ограничения;
- unverified — данные ещё не прошли проверку;
- conflicting — имеются несовместимые значения/источники;
- incomplete — не хватает метаданных, необходимых для оценки;
- unknown — качество не установлено.

Не трактовать эти слова как числовую вероятность правильности.

### 3.3 Пригодность для модели
Пригодность вычисляется на момент использования и зависит от:
- требуемого моделью типа свойства;
- совместимости размерности и basis;
- наличия обязательных условий (T, P, фаза, среда и т. п.);
- попадания текущих условий в подтверждённый диапазон применимости;
- политики модели к качеству/происхождению данных;
- проверки лицензии, если данные поставляются в распространяемом каталоге.

Неполная запись может храниться. Блокируется только расчёт, для которого конкретные недостающие или несовместимые данные обязательны. Оценочное значение нельзя молча повышать до verified.

## 4. ThermoConstantRecord: равновесные константы

Для K, Ka, Kb и Ksp недостаточно одного числового значения.

Минимальные логические метаданные:
- тип константы и связанное равновесие/реакция;
- basis: activity / concentration / pressure / fugacity / иной явно определённый basis;
- стандартное состояние для соответствующих компонентов;
- соглашение о размерности или безразмерности;
- температура и её допустимый диапазон;
- давление и его допустимый диапазон, если значимо;
- фаза, растворитель/среда и модель активности, если применимо;
- значение, uncertainty и значащие цифры;
- источник, версия/дата, метод и условия применимости.

Правила:
- activity-based термодинамическую константу нельзя напрямую подставлять как concentration-based константу без корректного преобразования и необходимых данных;
- нельзя переносить константу на другую температуру без валидированной зависимости и входных термодинамических данных;
- нельзя экстраполировать за диапазон источника без явно поддержанной и валидированной модели;
- отсутствие стандартного состояния или basis означает, что запись не является calculation-ready;
- для идеального приближения модели всё равно должны явно указывать принятое приближение и соответствующую конвенцию.

## 5. Единицы и безопасные преобразования

Преобразование допускается только если:
1. исходная и целевая величины имеют совместимую размерность;
2. известны все необходимые коэффициенты/контекст;
3. преобразование не меняет физический basis без явной модели;
4. результат сохраняет прослеживаемость исходного значения и преобразования.

Обязательные отрицательные случаи:
- mol/L → mol/kg без плотности/состава/температурного контекста, требуемого выбранным преобразованием;
- mol/kg → mol/L без соответствующих данных о растворе;
- масса → количество вещества без молярной массы;
- количество вещества → концентрация без объёма раствора и согласованного определения концентрации;
- массовая концентрация → молярная концентрация без молярной массы;
- перенос значения между разными фазами/средами без модели и подтверждённых данных;
- использование давления вместо безразмерной активности или наоборот без корректной стандартной конвенции.

Единицы должны быть связаны с физической размерностью; строковое совпадение символов единиц само по себе не доказывает совместимость.

## 6. Матрица требований к данным по моделям

Это предварительная матрица A1 для согласования с A3/A4, а не исчерпывающий контракт solver.

| Расчётный контекст | Минимально требуемые данные | Условия блокировки |
|---|---|---|
| Идентификация/баланс атомов и заряда | формула, состав, заряд; фазовый контекст Species отдельно | неизвестная/невалидная формула или заряд, несогласованный состав |
| PV=nRT для идеального газа | количество вещества, абсолютная температура, абсолютное давление или объём; согласованные единицы | отсутствует необходимая переменная, невалидные значения или несовместимые единицы |
| Водное равновесие кислота/основание | стехиометрия и заряд участников; нужные Ka/Kb; basis, стандартное состояние, T, среда и модель активности/идеальное приближение | неизвестная константа, неподдерживаемый basis/модель, вне диапазона применимости |
| Растворимость/осаждение через Ksp | стехиометрия растворения; Ksp с basis/standard state/T/средой; требуемые концентрации/активности и модель | Ksp без метаданных, недостаточные исходные концентрации/активности, несовместимая модель |
| Кинетика | kinetic parameter set и rate law от A4; размерности k должны соответствовать порядкам и basis скорости; provenance/applicability | отсутствует rate law или параметры, размерность k не согласована, T вне применимости |
| Энциклопедическая карточка | идентичность и все известные свойства с provenance/status | карточка может быть неполной; неизвестные поля отображаются как неизвестные, не подставляются |

A1 отвечает за типизацию свойств, единиц, provenance и applicability. Конкретные математические требования моделей и DTO принадлежат A3/A4 и должны быть согласованы с ними.

## 7. HazardRecord и полнота данных об опасности

HazardRecord должен отделять:
- систему классификации и её редакцию/юрисдикцию;
- класс/категорию опасности;
- H-statements и P-statements, если источник их предоставляет;
- транспортную классификацию отдельно от классификации опасности для здоровья/окружающей среды;
- источник, версию/дату, дату извлечения;
- полноту охвата и перечень отсутствующих разделов.

Предлагаемые состояния полноты:
- not_assessed — оценка полноты не выполнялась;
- absent — проверенная запись для данной системы/источника отсутствует;
- partial — доступны отдельные разделы, перечислить какие;
- complete_for_declared_scope — покрыты все поля заявленного набора/юрисдикции; это не означает абсолютную полноту всех возможных опасностей.

Запрещён вывод «безопасно» из отсутствия HazardRecord, отсутствия H/P statements или отсутствия предупреждения. Отображаемая формулировка должна сообщать источник, дату и область полноты. Справочная карточка не заменяет SDS и лабораторные инструкции.

## 8. Offline catalog и лицензирование

Allowlist ведётся не только на уровне домена/поставщика, но и на уровне dataset/record/field, когда источник агрегирует сторонние данные.

Для включения поля в redistributable bundle необходимы:
- идентифицируемый первичный источник значения;
- установленная лицензия/условия именно для этого материала;
- подтверждение разрешения на офлайн-копирование и распространение в составе приложения;
- выполнение требований атрибуции, notice, share-alike и иных условий, если применимо;
- сохранённые provenance и лицензионное свидетельство.

Статусы допуска:
- approved_for_redistribution — конкретное поле/набор проверен для включения;
- local_review_only — можно исследовать локально, но распространение не разрешено/не подтверждено;
- blocked_unknown_license — условия неизвестны или не проверены;
- blocked_restricted — известные условия несовместимы с распространением.

Наличие открытого API или возможность скачать данные не является доказательством разрешения на включение в распространяемый offline bundle. Для агрегаторов лицензия платформы не должна автоматически приписываться всем полям сторонних поставщиков.

## 9. Версионирование и миграции

До фиксации общего schema_version интегратором A1 предлагает следующие правила:
- версия схемы должна быть явной на границе сериализации/набора данных;
- миграция должна быть детерминированной и проверяемой;
- неизвестные поля старой/новой версии не должны молча переинтерпретироваться;
- если старый формат не содержит basis, unit, provenance или applicability, миграция не должна выдумывать эти данные; поле получает явный unknown/incomplete статус;
- несовместимые изменения требуют новой версии схемы и описания migration path;
- исходная запись/значения должны оставаться восстанавливаемыми либо миграция должна явно документировать потерю информации;
- после миграции выполняются повторные проверки размерностей, идентичности, provenance и расчётной применимости.

Общий формат версии и error envelope остаётся решением интегратора; A1 не закрепляет собственный конкурирующий механизм.

## 10. A1 acceptance matrix

### Позитивные проверки
- Справочное свойство с корректными единицами, source_id, версией источника, retrieved_at и применимостью принимается.
- Пользовательское свойство без внешнего источника сохраняется с явным user_defined происхождением и не маскируется под reference.
- Неполная пользовательская запись сохраняется, если идентифицирующие поля допустимы.
- Значение константы равновесия принимается для модели только при совместимых basis, standard state, условиях и размерности.
- Перевод массы в mol разрешается при известной молярной массе с корректной размерностью.
- HazardRecord со статусом partial отображает известные разделы и отсутствующие разделы раздельно.
- Миграция старой записи без provenance сохраняет её как incomplete/unknown, не придумывая источник.

### Негативные проверки
- Численное свойство без единицы/размерности не используется в расчёте.
- Неизвестное значение не интерпретируется как 0.
- Molarity не подменяется molality и наоборот без необходимых данных.
- Константы с разными basis не смешиваются.
- K без standard state/applicability не считается calculation-ready.
- Значение вне диапазона T/P/фазы не используется без валидированного правила.
- Поле с неизвестной лицензией не включается в redistributable bundle.
- Отсутствие hazard record не создаёт состояние «опасность отсутствует» или «безопасно».
- Hypothetical/user_defined статус не теряется при передаче результата дальше по цепочке.
- Несовместимая schema version не мигрируется молча.

## 11. Открытые решения интегратора / других агентов

1. SubstanceRecord ↔ SpeciesRef: точная граница стабильной сущности и фазового контекста — согласовать с A2.
2. Basis, standard state, activity model и минимальные поля EquilibriumProblem — согласовать с A3.
3. Rate-law-specific dimensions и kinetic parameter applicability — согласовать с A4.
4. Поля HazardRecord и представление completeness в карточке — согласовать с A5.
5. Общий schema_version, Unit Registry, null/missing semantics и Error Envelope — решение интегратора.
6. Конкретный набор источников/полей для allowlist — только после проверки условий каждого набора/поля; в этом документе лицензии не утверждаются.
7. Точные численные требования/порог качества для каждой модели — согласовать с владельцами моделей; универсальный порог verified для всех расчётов не вводится.

## 12. Не входит в этот addendum

- реализация parser/AST, балансировщика, solver, кинетики, UI или каталожного импорта;
- выбор численных benchmark fixtures без первичного источника, условий, basis, uncertainty и лицензии;
- утверждение лицензий или юридическое заключение;
- окончательная фиксация межагентных DTO, Unit Registry или общей версии схемы.


## 13. Уточнение границы A1 ↔ A2 по запросу A2 (2026-11-03)

Ниже — позиция A1 для интеграционного согласования, а не замороженный публичный DTO.

### 13.1 Что несёт ReactionTerm

- Parsed reaction term должен сохранять формульное представление/FormulaAST, заряд и фазовый контекст, выданные A2, а также коэффициент и устойчивый идентификатор исходного терма.
- Для каталогового вещества допускается отдельная необязательная ссылка на substance_id (либо versioned catalog reference, если такую форму выберет интегратор). Эта ссылка появляется только после явного разрешения/выбора записи каталога.
- Для формулы, которой нет в каталоге, ReactionTerm остаётся parsed/unresolved species descriptor: FormulaAST + phase context + source-term identity. Нельзя создавать фиктивный substance_id, вычислять его из формулы или автоматически регистрировать запись каталога при парсинге.
- Разрешение формулы в каталог — отдельная операция catalog lookup/selection, не обязанность FormulaParser и не часть балансировки.
- Один substance_id не заменяет фазовый контекст: одна каталоговая химическая сущность может участвовать в разных фазах/состояниях. И наоборот, одинаковая формула сама по себе не доказывает, что две независимые каталоговые записи тождественны.

### 13.2 Phase boundary

- На логическом уровне A1 подтверждает разделение: phase не входит в SubstanceRecord identity; phase относится к Species/ReactionTerm occurrence.
- A2 сейчас выдаёт UNSPECIFIED, SOLID, LIQUID, GAS, AQUEOUS. Временный адаптер A1 A2PhaseAdapter переводит четыре явных значения в старые lowercase tokens и отклоняет UNSPECIFIED/unknown. Это локальная совместимость, не решение общего wire enum.
- Рекомендация A1 интегратору: утвердить один типизированный enum/набор стабильных wire tokens для всех потребителей и явно сохранить состояние UNSPECIFIED/unknown как отсутствие установленной фазы; не превращать его в aq, g или другую фазу по умолчанию. До решения интегратора адаптер должен оставаться явным на границе, а call site — принадлежать модулю, который соединяет A2 parser с каталогом/экспериментом, не скрытой нормализацией в нескольких потребителях.
- A1 не утверждает lowercase или uppercase сериализацию в одиночку.

### 13.3 Duplicate terms and consumer contract

- Синтаксические исходные термы остаются отдельными в parsed reaction и сохраняют source-term IDs.
- Агрегация одинаковых formula+phase термов допустима только как внутренняя переменная конкретного балансировщика/solver; агрегированный результат обязан сохранять полный список исходных term IDs.
- Downstream consumer не должен терять происхождение термов или произвольно распределять агрегированный коэффициент между исходными термами.
- Стехиометрический коэффициент не задаёт kinetic order и сам по себе не определяет равновесную константу.

### 13.4 A1 ответы на вопросы A2

1. Catalog-backed reference: optional substance_id/versioned catalog ref attached after explicit lookup; no formula-derived ID.
2. Unmatched user formula: parsed/unresolved descriptor; save as user-defined catalog entry only after an explicit user/catalog operation, not as a parser side effect.
3. Phase: phase belongs to ReactionTerm/species occurrence; common enum/wire tokens require integrator decision; preserve unspecified distinctly.
4. Duplicate aggregation: preserve source terms in AST; aggregate only in solver with source IDs retained.
5. A3/A4 minimum fields: A1 confirms identity/composition/charge/phase/source-term identity/coefficient separation; arrow/reversibility is reaction semantics; kinetic order and K/k parameters remain explicit model inputs owned by A3/A4, never inferred from coefficient or arrow.



## 14. Подтверждение A2 и открытые потребительские контракты (2026-11-03)

### 14.1 Ответ A2 на позицию A1

A2 подтвердил принятие логической позиции A1 в комментарии PR #5 (comment ID 6599229884) и отразил её в A2 DRAFT specification, commit `010b97c470068a05c72c155ade5ffe23e152cddd`:

- catalog-backed ReactionTerm несёт optional `substance_id` только после явного catalog lookup/selection;
- unmatched input остаётся unresolved parsed species descriptor (FormulaAST + phase context + source-term ID), без искусственного catalog ID и implicit registration;
- phase — контекст occurrence, не часть FormulaAST/SubstanceRecord identity;
- `UNSPECIFIED` сохраняется явно; временный phase adapter не утверждает общий enum;
- исходные термы остаются раздельными, solver aggregation сохраняет все source IDs и не перераспределяет коэффициенты.

A1 считает эти пункты согласованной логической границей A1↔A2 для дальнейшей интеграционной работы. Это не утверждение DTO, phase wire enum или OpenSpec baseline. A2 подтвердил успешную CI-проверку указанного docs-only commit в run #41605749090; это подтверждает документационный head, но не меняет статус спецификации DRAFT.

### 14.2 Ожидаемые подтверждения A3/A4

Запросы к A3 и A4 опубликованы соответственно в PR #4 comment #6599307606 и PR #6 comment #6599308665. На момент обновления документа ответы с точным consumer field contract ещё не получены. До их получения матрица раздела 6 остаётся предварительной: A1 не выбирает за A3/A4 конвенции равновесия, rate law, единицы кинетических параметров или поведение solver.

### 14.3 A5 — hazard completeness consumer boundary

A1 сохраняет ответственность за семантику HazardRecord и completeness states. A5 отвечает только за представление в интерфейсе. При интеграции отображение должно сохранять различие между `not_assessed`, `absent`, `partial` и `complete_for_declared_scope`, показывать declared scope/source/date и никогда не преобразовывать отсутствие данных в утверждение «безопасно». Точный UI treatment остаётся за A5 после согласования стабильного контракта.


## 15. Уточнение требований A1 по текущему baseline A4 (2026-11-03)

A4 опубликовал benchmark matrix `docs/engineering/a4-solver-benchmark-matrix.md` (commit `143ed42b1854c723e05599dd329a5e2fd2d8401b`). Это документированный контракт текущей кинетической модели, а не утверждение общего DTO:

- состояние — количества веществ (n_i), mol; концентрация (c_i=n_i/V), mol·m⁻³;
- объём постоянен, система закрытая и изотермическая;
- объёмная скорость (r_j=k_j\prod_i c_i^{\alpha_{ij}}), mol·m⁻³·s⁻¹; скорость продвижения реакции (\dot\xi_j=Vr_j), mol·s⁻¹;
- кинетические порядки — явные неотрицательные вещественные входы и не выводятся из стехиометрических коэффициентов;
- A4 фиксирует размерностную зависимость константы скорости от суммы порядков: `(concentration)^(1 - sum(alpha)) / time` для выбранной объёмной формы закона скорости.

Следствие для A1: запись rate constant должна ссылаться на конкретную форму rate law и её набор порядков (либо на идентификатор/версию модели), концентрационную базу и размерность. Нельзя хранить универсальное поле `k` без указания закона скорости и контекста. Если сумма порядков меняется, размерность k меняется; нельзя переиспользовать численное значение k между законами с разными порядками без преобразования и обоснования.

Это уточняет минимальные требования к A4-потребляемым данным, но не решает ещё открытые вопросы сериализации, единиц общего Unit Registry, точной структуры RateConstant и поведения при температурной зависимости. В текущем A4 benchmark baseline температурная зависимость/Arrhenius не входят. A1 запросил у A4 точное подтверждение потребительского контракта; до ответа этот пункт остаётся согласованным по физической размерности с опубликованным описанием модели, но не утверждённым общим DTO.

## 16. Уточнение aqueous consumer boundary по текущему A3 reference core (2026-11-03)

В PR #4 A3 зафиксировал, что текущая реализация остаётся семью benchmark fixtures и не является общей speciation API. В частности, текущие ограничения включают gamma=1 aqueous approximations, concentration-based pH, численные equilibrium constants без полноценной provenance/standard-state записи, один AgCl solid, предположения о нейтральной подаче AgNO3/NaCl, идеальногазовые давления без fugacity и локальный reliability flag. Общие elemental/charge matrix validation, reaction-rank diagnostics, typed thermodynamic metadata и shared result/error contracts оставлены будущей интеграционной работой.

### Следствия для A1

1. Нельзя считать численное Ka/Kb/Ksp/Kp из текущей fixture самоописывающимся или переносимым на общий каталог. До появления записи с reaction definition, basis, standard state, medium/phase, T applicability, uncertainty и provenance оно остаётся benchmark-local/unqualified input.
2. A1 не должен трактовать gamma=1 как универсальную характеристику aqueous data. Это явное допущение конкретного текущего A3 fixture/model; любые коэффициенты активности или ionic-strength dependencies требуют отдельного model contract и данных.
3. Concentration-based pH не следует смешивать с thermodynamic activity-based pH. Property metadata и результаты должны сохранять basis/convention, а преобразование между ними не предполагается автоматически.
4. AgCl solid и neutral AgNO3/NaCl feed assumptions ограничивают применимость соответствующих fixture; A1 не распространяет их на все solid phases или произвольные ionic feeds.
5. Ideal-gas pressure assumptions не являются fugacity model. Нельзя помечать соответствующие Kp/pressure inputs как применимые к неидеальному газу без отдельной модели и supporting data.
6. A3 сообщение пока не подтверждает полный список полей consumer DTO, точную конвенцию H+/H3O+/water, quality eligibility или typed failure mapping. Эти решения остаются открытыми; перечисленные пункты фиксируют только явно объявленные ограничения текущей реализации.

Источник: PR #4, комментарий A3 6599473392 от 2026-11-03. Это уточнение применимости текущего benchmark core, не утверждение общего aqueous DTO и не одобрение OpenSpec baseline.

## 17. Зафиксированные требования потребителя A3 после ответа (2026-11-03)

A3 ответил на вопросы A1 в PR #4, comment `6600097355`. Ниже фиксируются требования текущего A3 reference core; это не общий DTO и не утверждение, что текущая реализация уже валидирует все метаданные.

### 17.1 Константы и термодинамическая конвенция

Текущие aqueous fixtures потребляют конечные положительные безразмерные константы в ideal-dilute convention с концентрационным стандартным состоянием \(c^\circ=1\,\mathrm{mol/L}\) и \(\gamma_i=1\):
- слабая кислота: \(HA\rightleftharpoons H^+ + A^-\), Ka;
- аммиачная fixture: Ka(NH4+) для \(NH_4^+\rightleftharpoons NH_3+H^+\), а не Kb(NH3); Kb текущей реализацией не потребляется;
- Kw: автопротолиз воды при активности жидкой воды, принятой равной 1;
- AgCl Ksp: \(AgCl(s)\rightleftharpoons Ag^+ + Cl^-\), активность твёрдой фазы 1, а Q приближается как \(([Ag^+]/c^\circ)([Cl^-]/c^\circ)\).

Для A1 это означает, что запись константы должна сохранять как минимум reaction/constant identity, value, uncertainty/precision, basis, dimensionless convention, standard state, T и applicability interval, при необходимости pressure interval, solvent/medium, phase, activity-model identifier/applicability, source/version/date/retrieval/method и provenance/quality. Activity-basis constant нельзя передавать в concentration approximation без валидированного преобразования. Вывод Ka из Kw/Kb допустим только при совместимых условиях и конвенциях и с сохранением provenance derivation.

### 17.2 Условия и идентичность

Текущие aqueous функции не принимают температуру и не вычисляют температурную поправку: вызывающая сторона должна предоставить константы, уже приведённые к одной совместимой объявленной температуре. A3 не предполагает 25 °C по умолчанию. Отсутствующие или несовместимые условия должны приводить к отказу адаптера, а не к догадке.

A3 требует stable identity либо unresolved FormulaAST descriptor, formula/composition, integer charge и phase. В текущем aqueous vocabulary используется H+ как shorthand hydrated proton; OH− — отдельный ион; H2O(l) является solvent с unit activity и не выступает отдельной решаемой species; H3O+ отдельно не представлена. Любое отображение H3O+ ↔ H+ должно быть явным и стехиометрически/термодинамически согласованным. AgCl(s) и aqueous ions имеют разные фазы.

### 17.3 Модель активности и качество

Текущий A3 поддерживает только явно заданное ideal-dilute gamma=1, c°=1 mol/L. Он не потребляет ionic strength, dielectric/solvent properties, ion-size/interaction parameters или complexation data. Неидеальная модель требует отдельного versioned model contract и собственных supporting inputs; неподдерживаемые записи отклоняются, а не идеализируются молча.

Provenance, quality, applicability и numerical convergence должны оставаться разными измерениями. Curated/reference и experimental данные могут быть допустимы при совпадении условий/basis/uncertainty. Calculated/estimated требуют явной политики модели и сохранения метода/неопределённости. User-defined допускаются только как явно exploratory и должны оставаться помеченными в downstream результатах. Hypothetical/unknown-origin не могут молча считаться reference/validated. License — отдельный redistribution gate, а не показатель численной валидности. Текущий scalar API эти правила не обеспечивает; их должен применять адаптер.

### 17.4 Отказы и gas convention

Адаптер должен отклонять отсутствующие/non-finite/non-positive константы, несовместимые basis/units/standard state, отсутствующие или несовместимые T/medium/phase, неподдерживаемую activity model и невалидные identity/charge/phase. Нельзя подставлять basis, 25 °C, gamma=1, proton mapping или missing value=0 по умолчанию. Текущие низкоуровневые сигналы A3: `EquilibriumInputError` для некорректного ввода и `EquilibriumConvergenceError` для численной неудачи; отображение в общий ErrorEnvelope решает интегратор.

Для газовых G01/G02 A3 уточнил: используется dimensionless Kp с pressure standard state \(p^\circ=1\,\mathrm{bar}\), идеальные partial pressures \(p_i=n_iRT/V\), без fugacity coefficients. Это не подтверждает применимость к неидеальным газам и не отменяет отдельного уточнения A1 по фазе I2 для GAS-02.

Источник: PR #4 comment `6600097355` от 2026-11-03. Требования описывают текущую fixture-конвенцию и будущую адаптерную проверку; они не замораживают shared DTO, Unit Registry, ErrorEnvelope или OpenSpec baseline.


## 18. HazardRecord completeness semantics — A1 proposal (2026-11-03)

A1 owns the meaning and completeness of hazard data; A5 owns presentation. This section defines domain semantics only. It does not prescribe UI layout or freeze a shared DTO. A5's exact consumer confirmation remains pending (PR #3 comment `6599360808`).

### 18.1 Completeness is scoped, not a safety score

The completeness state applies to a declared assessment scope, not to the substance universally. A scope should identify, where applicable:
- subject identity (stable Substance/Species reference, with phase/form distinction where hazard classification depends on it);
- jurisdiction or regulatory framework;
- source/document and its edition/version;
- assessed hazard domains/sections (for example physical, health, environmental);
- assessment date and source publication/effective date.

The state must never be interpreted as a probability of harm, severity score, exposure assessment, or statement that the substance is safe.

### 18.2 Proposed completeness states

| State | Domain meaning | Required interpretation |
|---|---|---|
| `not_assessed` | No assessment was performed or no trustworthy assessment evidence is available | Unknown; do not infer absent hazards or safety |
| `absent` | Assessment was performed for the declared scope and found no applicable hazard information/classification in that scope | Means absent within that assessed scope only; not globally hazard-free |
| `partial` | Some declared sections/domains have evidence, while others are missing, unavailable, stale, conflicting or not assessed | Preserve which sections are present and which are missing/uncertain |
| `complete_for_declared_scope` | All required sections for the explicitly declared scope have been assessed and the record has no unresolved required-section gaps | Complete only for that exact scope/source/version/date; never universal “safe” |

A missing record is not equivalent to `absent`. The `absent` state requires positive evidence that the declared scope was actually assessed.

### 18.3 Evidence and conflict handling

A hazard assertion should retain its source/document identity, edition/version, jurisdiction, publication/effective date, retrieval timestamp, relevant section/endpoint, and exact assertion (classification, H/P statement or other hazard datum). If multiple sources disagree:
- retain each source assertion and its provenance;
- represent conflict explicitly rather than silently selecting the most reassuring or newest value;
- do not collapse disagreement into `absent` or `complete_for_declared_scope`;
- any resolution/precedence policy must be explicit, versioned and scoped to a regulatory use case.

Staleness is separate from completeness. A record can be complete relative to an old source while stale for a current regulatory decision. Preserve both source date and retrieval date; do not silently refresh or overwrite historical evidence.

### 18.4 Negative and acceptance semantics

- No HazardRecord, no H/P statements, unavailable source, or missing section must never produce a “safe”, “non-hazardous” or equivalent positive safety conclusion.
- `absent` is valid only with evidence of an assessment over a declared scope.
- `complete_for_declared_scope` requires all required sections for that declared scope and source edition to be accounted for.
- A partially available source remains `partial`; missing sections are explicit.
- Conflicting sources remain visible as conflict; completeness cannot hide unresolved disagreement.
- Stale data remains marked stale independently of completeness.
- Subject identity mismatch (including substance form/phase where relevant) prevents attaching the assertion to a different catalog entity.
- User-entered or estimated hazard assertions retain their origin and cannot silently become authoritative regulatory classifications.

### 18.5 Open consumer and policy decisions

A5 has not yet confirmed its minimum fields for rendering unavailable, stale and conflicting hazard evidence. The integrator/owner must also decide whether a shared hazard schema needs additional controlled vocabularies for jurisdiction, hazard domain, source edition and regulatory framework. A1 does not select a global source-precedence policy or legal/regulatory interpretation in this proposal.

Source of coordination request: PR #3 comment `6599360808`, 2026-11-03. This is an A1 semantic proposal, not A5 acceptance or OpenSpec baseline approval.


## 19. Data origin, review transitions and model eligibility — A1 proposal (2026-11-03)

This section makes explicit that the six origin classes are not interchangeable quality grades and are not a single linear promotion ladder. Origin describes how an assertion came to exist; review/quality describes what has been checked; model eligibility describes whether a particular consumer may use it. These dimensions must remain independent.

### 19.1 Independent dimensions

Every candidate property assertion should preserve, where applicable:

1. **Origin class** (proposed closed vocabulary): `curated_reference`, `experimental`, `calculated_estimated`, `user_defined`, `hypothetical`, `unknown`.
2. **Review/quality state**: at minimum `unreviewed`, `reviewed`, `rejected`, with review evidence, reviewer/process identity, timestamp and ruleset/version. A future richer vocabulary may distinguish validation dimensions, but must not overload origin.
3. **Applicability**: the declared model/property context and conditions against which the assertion was checked.
4. **Eligibility decision**: a scoped decision for a named model and model-contract version, with explicit reasons and the policy version used.
5. **Redistribution disposition**: independent rights decision from the source/license gate in the source-license evidence memo. Numerical validity never grants redistribution rights.

A single global boolean such as `validated` or `trusted` is insufficient: a value may be reviewed but inapplicable to a model, scientifically eligible but non-redistributable, or useful for exploration but not reference calculations.

### 19.2 Origin semantics and default posture

| Origin | Meaning | Default calculation posture |
|---|---|---|
| `curated_reference` | Selected/reference assertion curated from an identified source or authoritative compilation | Candidate only; require source, conditions, units/basis, uncertainty/precision and model applicability checks |
| `experimental` | Measurement or experimental result, with method and conditions | Candidate only; require method, conditions, uncertainty and identity match; do not assume universally superior to curated data |
| `calculated_estimated` | Derived, predicted, fitted or estimated value | Ineligible by default until method/model, inputs, uncertainty and validation policy are supplied and the consuming model explicitly permits it |
| `user_defined` | Supplied by a user or caller | Exploratory-only by default; preserve caller/source identity and propagate the designation to downstream results |
| `hypothetical` | Proposed, theoretical or not empirically/reference established entity or property | Ineligible for validated/reference calculations; may be used only by an explicitly hypothetical workflow |
| `unknown` | Origin cannot be established | Fail closed: no validated calculation eligibility and no redistribution approval |

No origin class automatically implies high quality, correct units, applicable conditions, or legal permission. Experimental does not automatically outrank curated reference; a comparison requires compatible measurand, method, conditions, uncertainty and a declared selection policy.

### 19.3 Allowed review transitions

The following is a conservative transition policy for an assertion, not a workflow implementation:

- New assertion starts as `unreviewed`; missing provenance or origin is retained as `unknown`, not guessed.
- `unreviewed → reviewed` is allowed only after the applicable identity, numeric/type, unit/dimension, basis/conditions, provenance, uncertainty/precision and domain checks are recorded with evidence.
- `unreviewed → rejected` is allowed when a check fails; the failed checks and evidence are retained.
- `reviewed → rejected` is allowed when new evidence invalidates the assertion or a previously hidden incompatibility is found; the prior review decision remains auditable.
- `rejected → reviewed` requires a corrected/new assertion or new evidence and a new review event. Do not erase the rejection history.
- A change to value, unit, basis, phase, conditions, source/version, method, uncertainty, identity, or transformation creates a new assertion/version and invalidates any eligibility decision that depended on the old content.
- Origin is immutable for a given assertion. If an experimental value is later curated, normalized, fitted or estimated, retain the original experimental assertion and create a separate derived/curated assertion linked by explicit derivation provenance; do not relabel the original.
- No automatic promotion from `user_defined`, `calculated_estimated`, `hypothetical` or `unknown` to `curated_reference` is permitted. Any new origin classification requires a distinct assertion and evidence of the new origin.

### 19.4 Model-specific eligibility decision

Eligibility is evaluated per model contract, not stored as a universal property of a value. A decision should identify:

- property assertion ID/version and subject identity;
- consumer model name and contract/version;
- required property semantics, dimensions, units and basis;
- required conditions and applicability interval;
- accepted origin classes and minimum review state;
- uncertainty/precision requirements and any transformation applied;
- decision (`eligible` / `ineligible` / `exploratory_only`) and machine-readable reasons;
- policy/ruleset version and decision timestamp.

A3's current ideal-dilute fixtures and A4's current kinetic model therefore have different eligibility predicates. For example, a dimensionless aqueous equilibrium constant with the wrong standard state is ineligible for the A3 fixture even if its source is curated; an A4 rate constant without a rate-law/model version, kinetic-order basis and dimensionally compatible k unit is ineligible even if numerically finite. Eligibility must not be inferred from origin alone.

### 19.5 Required negative acceptance cases

- A finite numeric value with `unknown` origin does not become calculation-eligible.
- A reviewed value with incompatible unit, basis, phase or conditions is ineligible for that model.
- A source with valid scientific data but unknown/restricted redistribution rights remains blocked from the relevant bundle/export.
- A user-defined value remains `exploratory_only` downstream; serialization, caching or adapter conversion cannot silently promote it.
- A calculated estimate without method, input provenance or uncertainty remains ineligible unless a named exploratory model explicitly allows it.
- A hypothetical property cannot satisfy a validated benchmark fixture by matching its numeric value.
- Updating an assertion's value, source version, conditions or method invalidates its previous review/eligibility decision.
- A derived assertion retains parent assertion references, transformation method/version and propagated uncertainty; it cannot inherit a stronger origin or rights status than justified by its inputs.
- Conflicting assertions remain separate; selecting one requires an explicit, versioned, context-specific selection policy and must preserve rejected/alternative candidates for audit.

### 19.6 Open decisions

The exact serialized enum names, review-event schema, eligibility reason vocabulary and policy ownership require integrator/product-owner agreement. This proposal does not freeze a shared DTO, prescribe a global source-ranking policy, approve any source for redistribution, or authorize implementation before OpenSpec baseline approval.

## 20. Schema evolution and migration compatibility — A1 proposal (2026-11-03)

This section defines domain-level migration invariants and acceptance scenarios for A1-owned chemistry records. It does not choose the repository-wide schema version format, serialization envelope, migration runner, or release policy; those remain integrator/product-owner decisions.

### 20.1 Versioning invariants

- Every persisted chemistry record and every catalog bundle must be interpretable against an explicit schema version. Missing version is not silently treated as the latest version.
- A schema version identifies structure and semantics, not merely field names. A change to unit meaning, standard-state convention, phase interpretation, origin semantics, completeness semantics or default behavior is a semantic change even if serialized shape is unchanged.
- A1-owned record types must be independently identifiable within the agreed shared envelope (for example Substance identity, Property assertion, Source provenance, Thermodynamic constant and Hazard assessment). A shared envelope/name/ID scheme is not selected by A1.
- Unknown fields may be preserved by a lossless pass-through implementation, but must not be interpreted as known semantics. Unknown enum values must be retained or rejected explicitly; they must never be mapped to a reassuring/default value.
- A reader must either support the exact schema version, perform a registered deterministic migration, or fail with an actionable incompatibility. Best-effort guessing is prohibited for scientific fields.
- Migration must be deterministic, idempotent for the same source version and target version, and non-destructive. Original input/version and migration provenance must remain recoverable.
- Migration must not manufacture scientific facts: no default temperature, pressure, phase, basis, standard state, uncertainty, source, license, hazard absence, or model eligibility.
- Migration of a record does not itself revalidate its scientific correctness, applicability, source rights or model eligibility.

### 20.2 Change classification and compatibility posture

| Change class | Example | Proposed compatibility posture |
|---|---|---|
| Additive optional metadata | Add retrieval timestamp or method citation without changing prior meaning | Potentially backward-readable; old records remain explicitly incomplete where field is required by a consumer |
| Additive required metadata | Consumer now requires standard state or phase | Old records remain readable only as incomplete/unqualified; calculation adapter rejects until enriched |
| Semantic reinterpretation | Change pH basis, K convention, phase token meaning, or hazard completeness meaning | Breaking semantic migration; require explicit versioned transformation or reject |
| Unit/dimension correction | Correct a value stored as mol/L but declared mol/m³ | Never relabel silently; require evidence-backed conversion and retain original assertion |
| Enum vocabulary change | Rename/partition origin, phase, quality or hazard state | Explicit mapping table; unknown/unmapped values preserved as unknown or rejected |
| Identity/key change | Replace formula-derived key with stable catalog identity | Preserve old key as migration alias/reference; never infer a canonical identity from formula alone |
| Provenance/license enrichment | Add source version or per-field license disposition | Enrichment requires evidence; absence remains unknown/blocked, not approved |
| Record removal/deprecation | Retire obsolete field or source | Preserve historical data and migration note; do not erase audit evidence |

Backward readability is not equivalent to calculation eligibility. A record may deserialize successfully yet remain blocked from a model because required basis, conditions, source or review evidence is absent.

### 20.3 Migration execution requirements

1. Identify source schema version and record type before parsing domain values.
2. Validate source structure and retain the original payload or a lossless archival representation.
3. Apply only a registered migration path with explicit source and target versions.
4. Record migration identifier/version, timestamp, tool/build version, input digest and warnings; exact envelope fields are for integrator agreement.
5. Preserve assertion identity/history and all source/field provenance. If a transformation changes value or semantics, create a new assertion/version linked to the original rather than overwriting it.
6. Re-run structural/domain validation after migration, then recompute model-specific eligibility from current policies. Never carry an old eligibility decision forward as authoritative.
7. Keep redistribution disposition independent; migration cannot turn unknown/restricted source data into redistributable data.
8. On unsupported version, missing required migration, lossy transformation, identity ambiguity or unresolvable semantic conflict, fail closed and report the record/path and reason. Do not partially publish a catalog bundle.

### 20.4 A1 migration acceptance matrix

| Case | Input condition | Expected outcome |
|---|---|---|
| M01 | Explicit supported current version, all required fields valid | Read and validate; eligibility still evaluated per model |
| M02 | Older version with registered lossless additive-field migration | Migrate deterministically; mark newly required but absent fields incomplete |
| M03 | Missing schema version | Reject or quarantine as unversioned; never assume current |
| M04 | Future/unknown schema version | Preserve opaque payload if supported, otherwise reject; never parse unknown semantics as current |
| M05 | Unknown enum token (phase/origin/hazard state) | Preserve as unknown/unmapped or reject; never map to a default safe/eligible state |
| M06 | Old bare numeric K/Ka/Kb/Ksp without basis/standard state/conditions | May retain as legacy descriptive datum; must remain calculation-ineligible |
| M07 | Old numeric property with missing or ambiguous unit | Do not infer unit; reject conversion and calculation eligibility |
| M08 | Molarity-to-molality conversion requested but solvent density/composition/temperature inputs absent | Reject conversion; retain original basis |
| M09 | Phase token migration where old value is ambiguous or UNSPECIFIED | Preserve unresolved/unspecified state; do not guess phase |
| M10 | Formula-based legacy identity lacks validated composition/charge mapping | Keep unresolved legacy reference; do not mint stable Substance ID by formula alone |
| M11 | Source provenance exists but license/redistribution rights absent | Preserve source assertion; block affected export/bundle |
| M12 | Legacy hazard record has no evidence of assessment scope | Map to not_assessed/unknown only when semantically justified; never map to absent or complete |
| M13 | Migration changes numeric value/unit/basis/conditions | Create linked transformed assertion with method and uncertainty; preserve original |
| M14 | Previous model eligibility exists but policy/model version changed | Re-evaluate; stale decision cannot authorize current use |
| M15 | Same migration is run twice on the same source/target version | Result is idempotent; no duplicate assertions or provenance events |
| M16 | One record in an import bundle fails a required migration | Fail bundle publication atomically or quarantine the failed record under an explicit policy; never silently omit it |

### 20.5 Open integration decisions

Integrator/product owner must decide the shared schema-version envelope, version numbering policy, migration registry/runner, unknown-field preservation guarantees, bundle atomicity/quarantine policy, and error mapping. A1 supplies domain invariants and test cases only. No migration code, serialized DTO or baseline implementation is authorized by this proposal.

## 21. A4 dimensional cross-check — fractional kinetic order (2026-11-03)

A4's TOL-05 discussion in PR #6 comments `6601157670` and `6601163898` provides a useful dimensional cross-check for section 15. For the current volumetric power-law rate

`r = k · Π(c_i ^ α_i)`

with `[r] = concentration/time`, the concentration exponent of `k` is:

`e_k = 1 − Σα_i`

and therefore `[k] = concentration^(1 − Σα_i) · time^−1`.

For the half-order A→B case (`Σα_i = 0.5`), `e_k = +0.5`, not `−0.5`. A4 explicitly corrected the fixture's unit exponent in commit `0ee1310ac45919b87bc032769f940280a962351c`; the preceding commit `5f37958df86e0f65f30b8afa459f78d4ccaf741f` had the incorrect exponent and is superseded. The corrected exact-head CI was still queued/in progress in A4's report, so this is recorded as a dimensional correction, not as a passed test or final A4 consumer-contract confirmation.

A1 acceptance implication: a rate-constant record or adapter must validate the exponent/dimension against the independently declared kinetic-order vector and the selected rate-law form. A numerically finite `k` with the wrong concentration exponent is dimensionally incompatible and must be rejected. This does not authorize A1 to define A4's serialized type or change A4 implementation.
