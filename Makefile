NASM ?= nasm
TARGET ?= heart

$(TARGET): heart.asm
	$(NASM) -f bin ./heart.asm -o $(TARGET)
	chmod +x $(TARGET)

clean:
	rm -f $(TARGET) || true
.PHONY: clean
