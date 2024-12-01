export const GridNav = {
  mounted() {

    this.selectionStart = null;
    this.currentLine = null;
    this.lineNumbers = document.querySelectorAll('[data-line-number]');
    this.lineCount = this.lineNumbers.length;

    this.isEditing = () => {
      return this.el.querySelector('textarea') !== null;
    };

    this.getCellAt = (rowIndex, colIndex) => {
      const element = document.querySelector(`[data-col-index="${colIndex}"][data-row-index="${rowIndex}"]`);
      if (element) {
          return element;
      } else {
          console.warn(`Element with data-col-index=${colIndex} and data-row-index=${rowIndex} not found.`);
      }
      return;
    };

    this.focusCell = () =>  {
      const targetCell = this.getCellAt(this.currentRow, this.currentCol);
        targetCell.focus();
    }

    this.handleKeyDown = (e) => {

      // Escape should work during editing -- to cancel edit
      // And outside editing, to clear selection? And to focus 
      // the whole grid if we're focused on a cell?
      if (e.key === 'Escape') {
        if (this.selectionStart !== null) {
          this.selectionStart = null;
          this.currentNumber = null;
          this.pushEvent("clear_selection", {});
        } else {
          this.pushEvent("cancel_edit");
        }
        return;
      }

      // Don't handle navigation when editing
      if (this.isEditing()) return;

      this.currentRow = document.activeElement.dataset.rowIndex;
      this.currentCol = document.activeElement.dataset.colIndex;
      // console.log("got currentRow" + this.currentRow)
      // console.log("got currentCol" + this.currentCol)

      if (e.key === ' ') {
        e.preventDefault();
        lineNumberEl = e.target.closest('[data-line-number]');
        if (!lineNumberEl) return;
        lineNumber = parseInt(lineNumberEl.dataset.lineNumber);
        
        if (!this.selectionStart) {
          // Start new selection
          this.selectionStart = lineNumber;
          this.currentLine = lineNumber;
          console.log("starting selection at line " + lineNumber)
          this.pushEvent("start_selection", {
            start: lineNumber,
            end: lineNumber
          });
        }
        return;
      }

      // Handle line number selection with Shift, if focused on a line number
      if (e.shiftKey && ['ArrowUp', 'ArrowDown'].includes(e.key)) {
        e.preventDefault();      
        console.log("this.selectionStart: " + this.selectionStart);
        console.log("this.selectionStart: " + this.selectionStart);
        if (this.selectionStart == null) return;  
        console.log("in a shift-arrow event; this.currentLine is " + this.currentLine + " and this.selectionStart is " + this.selectionStart);
        console.log("this.lineNumbers[i]: " + this.lineNumbers[this.currentLine].innerHTML);
        // Find next/previous line number element
        const nextLineNum = e.key === 'ArrowUp' ? Math.max(this.currentLine - 1, this.selectionStart) : Math.min(this.currentLine + 1, this.lineCount);
        // const direction = e.key === 'ArrowUp' ? 'previousElementSibling' : 'nextElementSibling';
        console.log("nextLineNum: " + nextLineNum);
        const nextEl = this.lineNumbers[nextLineNum];
        // const nextEl = lineNumberEl.parentElement[direction];
        console.log("nextEl: " + nextEl.innerHTML)
        if (nextEl && nextEl.dataset.lineNumber) {
          // const lineNumber = parseInt(nextEl.dataset.lineNumber);
          if (this.selectionStart !== null) {
            console.log("this.selectionstart ");
            this.currentLine = nextLineNum;
            this.pushEvent("update_selection", {
              start: this.selectionStart,
              end: nextLineNum
            });
            nextEl.focus();
          }
        }
        return;
      } 

      // Handle Enter to start editing, or to enter the grid nav if the parent
      // tabbable element is selected
      if (e.key === 'Enter' && !this.isEditing()) {
        if (document.activeElement.classList.contains("editable")) {
          e.preventDefault();
          this.pushEvent("start_edit", {
            row_index: this.currentRow,
            col_index: this.currentCol
          });
        }
        else if (document.activeElement.id == "annotated-content") {
          e.preventDefault();
          this.currentRow = 0;
          this.currentCol = 0;
          this.focusCell();
        }
        return;
      }

      // Only handle arrow keys
      // if (!['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].includes(e.key)) return;
      
      e.preventDefault();
      
      const rows = Array.from(this.el.querySelectorAll('[role="row"]'));
      const maxRow = rows.length - 2; // minus one because header row doesn't count, minus another because zero-indexed (TODO: make rows start at 1)
      const maxCol = this.el.querySelectorAll('[role="columnheader"]').length - 1;
      // console.log("maxRow: "+ maxRow + "; maxCol: " + maxCol);
      
      switch (e.key) {
        case 'ArrowUp':
          this.currentRow = Math.max(0, this.currentRow - 1);
          console.log("ArrowUp to " + this.currentRow + ", " + this.currentCol);
          this.focusCell();
          break;
        case 'ArrowDown':
          this.currentRow = Math.min(maxRow, this.currentRow + 1);
          console.log("ArrowDown to " + this.currentRow + ", " + this.currentCol);
          this.focusCell();
          break;
        case 'ArrowLeft':
          this.currentCol = Math.max(0, this.currentCol - 1);
          console.log("ArrowLeft to " + this.currentRow + ", " + this.currentCol);
          this.focusCell();
          break;
        case 'ArrowRight':
          this.currentCol = Math.min(maxCol, this.currentCol + 1);
          console.log("ArrowRight to " + this.currentRow + ", " + this.currentCol);
          this.focusCell();
          break;
      }
    };

    this.getCurrentLineRange = () => {
      const cell = this.getCellAt(this.currentRow, 0);
      if (!cell) return null;

      return {
        first: parseInt(cell.dataset.firstLine),
        last: parseInt(cell.dataset.lastLine)
      };
    };
    
    this.el.addEventListener('keydown', this.handleKeyDown);
  },

  destroyed() {
    this.el.removeEventListener('keydown', this.handleKeyDown);
  }
};