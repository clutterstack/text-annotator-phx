export const GridNav = {
  mounted() {

    this.mode = this.el.dataset.mode;
    this.isSelecting = false;
    this.selectionStart = null;
    this.currentLine = null;
    this.lineNumbers = document.querySelectorAll('[data-line-number]');
    this.lineCount = this.lineNumbers.length;

    this.handlekeyup = (e) => {

      // Escape should work during editing, too (to cancel editing).
      this.escapeKey(e.key);

      // Handle navigation and line chunking when not editing
      if (this.isEditing()) return;

      e.preventDefault();

      if (this.mode === "notes" && this.isSelecting) {
        this.chunkSelection(e);
      }

      this.currentRow = document.activeElement.dataset.rowIndex;
      this.currentCol = document.activeElement.dataset.colIndex;

      // Handle Enter to start editing, or to enter the grid nav if the parent
      // tabbable element is selected
      this.enterKey(e.key);

      // Navigate grid cells with arrow keys
      if (!this.isSelecting) {
        this.arrowNav(e.key);
      }
    };

    this.arrowNav = (key) => {
      const rows = Array.from(this.el.querySelectorAll('[role="row"]'));
      const cellRow = Number(this.currentRow);
      const cellCol = Number(this.currentCol);
      const maxRow = rows.length - 2; // minus one because header row doesn't count, minus another because zero-indexed (TODO: make rows start at 1)
      const maxCol = this.el.querySelectorAll('[role="columnheader"]').length - 1;
      // console.log("maxRow: "+ maxRow + "; maxCol: " + maxCol);
      
      switch (key) {
        case 'ArrowUp':
          this.currentRow = Math.max(0, cellRow - 1);
          console.log("ArrowUp to " + this.currentRow + ", " + this.currentCol);
          this.focusCell();
          break;
        case 'ArrowDown':
          this.currentRow = Math.min(maxRow, cellRow + 1);
          console.log("ArrowDown to " + this.currentRow + ", " + this.currentCol);
          this.focusCell();
          break;
        case 'ArrowLeft':
          this.currentCol = Math.max(0, cellCol - 1);
          console.log("ArrowLeft to " + this.currentRow + ", " + this.currentCol);
          this.focusCell();
          break;
        case 'ArrowRight':
          console.log("Right arrow nav; currentCol is " + this.currentCol + " and maxCol is " + maxCol);
          this.currentCol = Math.min(maxCol, cellCol + 1);
          console.log("ArrowRight to " + this.currentRow + ", " + this.currentCol);
          this.focusCell();
          break;
      }
    }

    this.escapeKey = (key) => {
      if (key === 'Escape') {
        if (this.selectionStart !== null) {
          console.log("this.selection")
          this.selectionStart = null;
          this.currentLine = null;
          this.isSelecting = false;
          this.pushEvent("cancel_selection", {});
          this.focusCell();
        } else if (this.isEditing()) {
          console.log("this.isEditing(): " + this.isEditing())
          this.pushEvent("cancel_edit");
          this.focusCell();
        } else {
          document.getElementById("annotated-content").focus();
        }
        return;
      }
    }

    this.enterKey = (key) => {
      if (key === 'Enter' && !this.isEditing()) {
        console.log("grid_nav hook detected an Enter key in mode " + this.mode)
        if (document.activeElement.id == "annotated-content") {
          this.currentRow = 0;
          this.currentCol = 2;
          this.focusCell();
        } 
        else
        {
          switch (this.mode) {
            case "content":
              console.log("mode is content");
              console.log("classes: " + document.activeElement.classList);
              if (document.activeElement.classList.contains("editable")) {
                this.startEdit();
              }
              break;
            case "notes":
              console.log("mode is notes");
              console.log("dataset.col? " + document.activeElement.dataset.col);
              switch (document.activeElement.dataset.col) {
                case "note":
                  this.startEdit();
                  break;
                case "content":
                  this.startSelect();
                  break;
              } 
              if (this.selectionStart !== null) {
                  console.log("gonna submitChunk");
                  this.submitChunk();
              }
              break; 
          }
        }   
      }
    }
      

    this.chunkSelection = (e) => {
      
      // Arrow through lines
      if (['ArrowUp', 'ArrowDown'].includes(e.key)) {
        console.log("this.currentLine is " + this.currentLine + " and this.selectionStart is " + this.selectionStart);
        console.log("this.lineNumbers[i]: " + this.lineNumbers[this.currentLine].innerHTML);
        // Find next/previous line number element
        const nextLineNum = e.key === 'ArrowUp' ? Math.max(this.currentLine - 1, this.selectionStart) : Math.min(this.currentLine + 1, this.lineCount);
        console.log("nextLineNum: " + nextLineNum);
        const nextEl = this.lineNumbers[nextLineNum];
        console.log("nextEl: " + nextEl.innerHTML)
        nextEl.focus();
        this.currentLine = nextLineNum;

        // Change selection if shift key was down
        // const lineNumber = parseInt(nextEl.dataset.lineNumber);
        if (e.shiftKey && this.selectionStart !== null) {
          console.log("nextLineNum is " + nextLineNum);
          this.pushEvent("update_selection", {
            start: this.selectionStart,
            end: nextLineNum
          });
        }
      }
      if (e.key === ' ' && this.isSelecting) {
        console.log("space key in chunkSelection")
        if (!this.selectionStart) {
          const lineNumber = this.currentLine;
          // Start new selection
          this.selectionStart = this.currentLine;
          console.log("starting selection at line " + this.currentLine)
          this.pushEvent("start_selection", {
            start: this.currentLine,
            end: this.currentLine
          });
        }
      }
    }

    this.startEdit = () => {
      console.log("this.startEdit invoked")
      this.pushEvent("start_edit", {
        row_index: this.currentRow,
        col_index: this.currentCol
      });
      return
    }
    
    this.startSelect = () => {
      this.isSelecting = true;
      lineNumberEl = document.activeElement.firstElementChild;
        if (!lineNumberEl) return;
        lineNumberEl.focus();
        // e.target.closest('[data-line-number]');
        lineNumber = parseInt(lineNumberEl.dataset.lineNumber);
        this.currentLine = lineNumber;
        console.log("lineNumberEl line number: " + lineNumberEl.dataset.lineNumber);
    }

    this.submitChunk = () => {
      this.pushEvent("rechunk");
    }

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
    };
    this.getCurrentLineRange = () => {
      const cell = this.getCellAt(this.currentRow, 2);
      if (!cell) return null;

      return {
        first: parseInt(cell.dataset.firstLine),
        last: parseInt(cell.dataset.lastLine)
      };
    };
    
    this.el.addEventListener('keyup', this.handlekeyup);
  },

  destroyed() {
    this.el.removeEventListener('keyup', this.handlekeyup);
  }
};