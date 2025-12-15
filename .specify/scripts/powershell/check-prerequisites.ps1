#!/usr/bin/env pwsh

# Объединенный скрипт проверки предварительных условий (PowerShell)
#
# Этот скрипт предоставляет унифицированную проверку предварительных условий для рабочего процесса Spec-Driven Development.
# Он заменяет функциональность, ранее распределенную по нескольким скриптам.
#
# Использование: ./check-prerequisites.ps1 [ОПЦИИ]
#
# ОПЦИИ:
#   -Json               Вывод в формате JSON
#   -RequireTasks       Требовать существование tasks.md (для фазы реализации)
#   -IncludeTasks       Включить tasks.md в список доступных документов
#   -PathsOnly          Только вывод переменных путей (без валидации)
#   -Help, -h           Показать сообщение справки

[CmdletBinding()]
param(
    [switch]$Json,
    [switch]$RequireTasks,
    [switch]$IncludeTasks,
    [switch]$PathsOnly,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

# Показать справку, если запрошено
if ($Help) {
    Write-Output @"
Использование: check-prerequisites.ps1 [ОПЦИИ]

Объединенная проверка предварительных условий для рабочего процесса Spec-Driven Development.

ОПЦИИ:
  -Json               Вывод в формате JSON
  -RequireTasks       Требовать существование tasks.md (для фазы реализации)
  -IncludeTasks       Включить tasks.md в список AVAILABLE_DOCS
  -PathsOnly          Только вывод переменных путей (без валидации предварительных условий)
  -Help, -h           Показать это сообщение справки

ПРИМЕРЫ:
  # Проверить предварительные условия задач (требуется plan.md)
  .\check-prerequisites.ps1 -Json
  
  # Проверить предварительные условия реализации (требуется plan.md + tasks.md)
  .\check-prerequisites.ps1 -Json -RequireTasks -IncludeTasks
  
  # Получить только пути функции (без валидации)
  .\check-prerequisites.ps1 -PathsOnly

"@
    exit 0
}

# Подключить общие функции
. "$PSScriptRoot/common.ps1"

# Получить пути функции и валидировать ветку
$paths = Get-FeaturePathsEnv

if (-not (Test-FeatureBranch -Branch $paths.CURRENT_BRANCH -HasGit:$paths.HAS_GIT)) { 
    exit 1 
}

# Если режим только путей, вывести пути и выйти (поддержка комбинированного -Json -PathsOnly)
if ($PathsOnly) {
    if ($Json) {
        [PSCustomObject]@{
            REPO_ROOT    = $paths.REPO_ROOT
            BRANCH       = $paths.CURRENT_BRANCH
            FEATURE_DIR  = $paths.FEATURE_DIR
            FEATURE_SPEC = $paths.FEATURE_SPEC
            IMPL_PLAN    = $paths.IMPL_PLAN
            TASKS        = $paths.TASKS
        } | ConvertTo-Json -Compress
    } else {
        Write-Output "REPO_ROOT: $($paths.REPO_ROOT)"
        Write-Output "BRANCH: $($paths.CURRENT_BRANCH)"
        Write-Output "FEATURE_DIR: $($paths.FEATURE_DIR)"
        Write-Output "FEATURE_SPEC: $($paths.FEATURE_SPEC)"
        Write-Output "IMPL_PLAN: $($paths.IMPL_PLAN)"
        Write-Output "TASKS: $($paths.TASKS)"
    }
    exit 0
}

# Валидировать обязательные директории и файлы
if (-not (Test-Path $paths.FEATURE_DIR -PathType Container)) {
    Write-Output "ОШИБКА: Директория функции не найдена: $($paths.FEATURE_DIR)"
    Write-Output "Сначала запустите /speckit.specify для создания структуры функции."
    exit 1
}

if (-not (Test-Path $paths.IMPL_PLAN -PathType Leaf)) {
    Write-Output "ОШИБКА: plan.md не найден в $($paths.FEATURE_DIR)"
    Write-Output "Сначала запустите /speckit.plan для создания плана реализации."
    exit 1
}

# Проверить tasks.md, если требуется
if ($RequireTasks -and -not (Test-Path $paths.TASKS -PathType Leaf)) {
    Write-Output "ОШИБКА: tasks.md не найден в $($paths.FEATURE_DIR)"
    Write-Output "Сначала запустите /speckit.tasks для создания списка задач."
    exit 1
}

# Построить список доступных документов
$docs = @()

# Всегда проверять эти опциональные документы
if (Test-Path $paths.RESEARCH) { $docs += 'research.md' }
if (Test-Path $paths.DATA_MODEL) { $docs += 'data-model.md' }

# Проверить директорию contracts (только если она существует и содержит файлы)
if ((Test-Path $paths.CONTRACTS_DIR) -and (Get-ChildItem -Path $paths.CONTRACTS_DIR -ErrorAction SilentlyContinue | Select-Object -First 1)) { 
    $docs += 'contracts/' 
}

if (Test-Path $paths.QUICKSTART) { $docs += 'quickstart.md' }

# Включить tasks.md, если запрошено и он существует
if ($IncludeTasks -and (Test-Path $paths.TASKS)) { 
    $docs += 'tasks.md' 
}

# Вывести результаты
if ($Json) {
    # Вывод JSON
    [PSCustomObject]@{ 
        FEATURE_DIR = $paths.FEATURE_DIR
        AVAILABLE_DOCS = $docs 
    } | ConvertTo-Json -Compress
} else {
    # Текстовый вывод
    Write-Output "FEATURE_DIR:$($paths.FEATURE_DIR)"
    Write-Output "AVAILABLE_DOCS:"
    
    # Показать статус каждого потенциального документа
    Test-FileExists -Path $paths.RESEARCH -Description 'research.md' | Out-Null
    Test-FileExists -Path $paths.DATA_MODEL -Description 'data-model.md' | Out-Null
    Test-DirHasFiles -Path $paths.CONTRACTS_DIR -Description 'contracts/' | Out-Null
    Test-FileExists -Path $paths.QUICKSTART -Description 'quickstart.md' | Out-Null
    
    if ($IncludeTasks) {
        Test-FileExists -Path $paths.TASKS -Description 'tasks.md' | Out-Null
    }
}
