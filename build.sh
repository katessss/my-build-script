#!/bin/sh


set -e

#для вывода сообщений об ошибках
error_exit() {
    echo "ОШИБКА: $1" >&2
    exit "${2:-1}"
}

# для очистки временного каталога
cleanup() {
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

# количество аргументов
if [ "$#" -ne 1 ]; then
    error_exit "После $0 должен быть передан 1 аргумент"
fi

# проверка на существование и права доступа
SOURCE_FILE="$1"
SOURCE_DIR=$(dirname "$SOURCE_FILE")
SOURCE_FILENAME=$(basename "$SOURCE_FILE")
if [ ! -f "$SOURCE_FILE" ] || [ ! -r "$SOURCE_FILE" ]; then
    error_exit "Исходный файл не найден или недоступен для чтения: $SOURCE_FILE"
fi

# считывание названия для сохранения
OUTPUT_FILENAME=$(grep '&Output:' "$SOURCE_FILE" | sed 's/.*&Output:[[:space:]]*//')

# проверка на пустоту
if [ -z "$OUTPUT_FILENAME" ]; then
    error_exit "Не удалось найти комментарий с именем выходного файла в формате '&Output: <имя_файла>'."
fi

# создание временного католога
TEMP_DIR=$(mktemp -d XXXXXX)

# удлаение католога при любом результате
trap cleanup EXIT HUP INT TERM


COMPILATION_SUCCESSFUL=false
case "$SOURCE_FILENAME" in
    *.c)
        echo "Обнаружен файл C. Компиляция с помощью cc..."
        if cc -o "$TEMP_DIR/$OUTPUT_FILENAME" "$SOURCE_FILE"; then
            COMPILATION_SUCCESSFUL=true
        else
            error_exit "Ошибка компиляции файла C." 5
        fi
        ;;
    *.cpp | *.cxx | *.cc)
        echo "Обнаружен файл C++. Компиляция с помощью g++..."
        if g++ -o "$TEMP_DIR/$OUTPUT_FILENAME" "$SOURCE_FILE"; then
            COMPILATION_SUCCESSFUL=true
        else
            error_exit "Ошибка компиляции файла C++." 5
        fi
        ;;
    *.tex)
        echo "Обнаружен файл TeX. Компиляция с помощью pdflatex..."
        if pdflatex -output-directory="$TEMP_DIR" -jobname="$OUTPUT_FILENAME" "$SOURCE_FILE"; then
            OUTPUT_FILENAME="$OUTPUT_FILENAME.pdf"
            COMPILATION_SUCCESSFUL=true
        else
            error_exit "Ошибка компиляции файла TeX." 5
        fi
        ;;
    *)
        error_exit "Неподдерживаемый тип исходного файла: $SOURCE_FILENAME" 4
        ;;
esac
if [ "$COMPILATION_SUCCESSFUL" = true ]; then
    if [ -f "$TEMP_DIR/$OUTPUT_FILENAME" ]; then
        mv "$TEMP_DIR/$OUTPUT_FILENAME" "$SOURCE_DIR/"
        echo "Сборка успешно завершена. Результат: $SOURCE_DIR/$OUTPUT_FILENAME"
    else
        error_exit "Скомпилированный файл не найден во временном каталоге." 6
    fi
fi
exit 0