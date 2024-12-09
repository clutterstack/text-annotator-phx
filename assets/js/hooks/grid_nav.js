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

      if (this.isSelecting) {
        this.chunkSelection(e);
      }

      // Handle Enter to start editing, or to enter the grid nav if the parent
      // tabbable element is selected
      this.enterKey(e.key);

      // Navigate grid cells with arrow keys
      if (!this.isSelecting) {
        this.arrowNav(e.key);
      }
    };

    this.handlemousedown = (e) => {

      if (e.target.closest(".line-number")) {
        console.log("set this.currentRow, this.currentCol to " + e.target.closest(".line-number").parentElement.dataset.rowIndex + ", " + e.target.closest(".line-number").parentElement.dataset.colIndex);
        this.currentRow = e.target.closest(".line-number").parentElement.dataset.rowIndex;
        this.currentCol = e.target.closest(".line-number").parentElement.dataset.colIndex;
        console.log("mousedown at " + e.target.closest(".line-number").innerText);
        this.isSelecting = true;
        this.selectionStart = Number(e.target.closest(".line-number").innerText);
        this.currentLine = this.selectionStart;
        console.log("on mousedown, changed this.selectionStart to " + this.selectionStart);
        console.log("also, typeof this.selectionStart is " + typeof(this.selectionStart))
        this.el.removeEventListener('mousedown', this.handlemousedown);
        this.el.addEventListener('mouseover', this.handlemouseover);
        this.el.addEventListener('mouseup', this.handlemouseup);
        this.el.addEventListener('mouseleave', this.handlemouseleave);
      }

    };
    
    this.handlemouseover = (e) => {
      e.preventDefault();

      if (e.target.closest(".line-number")) {
        e.preventDefault();
        const nowline = e.target.closest(".line-number");
        console.log("handlemouseover");
        // console.log("mouseover at " + e.target.closest(".line-number").innerText);
        nowline.classList.remove("selectedline"); // in case I'm duplicating this class
        const linediff = nowline.innerText - this.currentLine;
        console.log("linediff: " + linediff );
        if (linediff > 0) {
          console.log("linediff is " + linediff + ". Adding class selectedline.")
          nowline.classList.add("selectedline");
        } else if (linediff < 0) {
          console.log("linediff is " + linediff + ". Removing class selectedline.")
          e.target.closest(".line-number").classList.remove("selectedline");
        }
        this.currentLine = Number(nowline.innerText);

        console.log("mouseover at " + e.target.closest(".line-number").innerText + ". this.currentLine updated to " + this.currentLine)
        console.log("also, typeof this.currentLine is now" + typeof(this.currentLine))
        // e.target.addEventListener('mouseleave', this.handlemouseleave, { once: true });
      }
    };

    this.handlemouseup = (e) => {
      // if (e.target.closest(".line-number")) {
        console.log("mouseup is updating selection. this.selectionStart is type " + typeof(this.selectionStart) + " and this.currentLine is type " + typeof(this.currentLine))
        this.pushEvent("update_selection", {
          start: this.selectionStart,
          end: this.currentLine
        });
        this.submitChunk();
        this.focusCell();

        this.selectionStart = null;
        this.el.removeEventListener('mouseup', this.handlemouseup);
        this.el.removeEventListener('mouseover', this.handlemouseover);
        this.el.removeEventListener('mouseleave', this.handlemouseleave);
      // }
    };

    this.handlemouseleave = (e) => {
      if (e.target.id == "annotated-content") {
        console.log("mouseleave of #annotated-content element");
        this.clearSelection();
      }
    };

    this.arrowNav = (key) => {
      if (['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].includes(key)) {
        this.currentRow = document.activeElement.dataset.rowIndex;
        this.currentCol = document.activeElement.dataset.colIndex;
  
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
    }

    this.escapeKey = (key) => {
      if (key === 'Escape') {
        if (this.isSelecting) {
          console.log("escapeKey: this.isSelecting was true")
          console.log("this.currentRow and this.currentCol are " + this.currentRow + ", " + this.currentCol)

          this.clearSelection();
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
      if (key === 'Enter' && !this.isEditing() && this.mode == "author") {
        console.log("grid_nav hook detected an Enter key")
        if (document.activeElement.id == "annotated-content") {
          this.currentRow = 0;
          this.currentCol = 2;
          this.focusCell();
        } 
        else { 
          // console.log("classes: " + document.activeElement.classList);
          if (document.activeElement.classList.contains("editable")) {
            this.startEdit();
          } 
          else if (document.activeElement.dataset.col == "line-num") {
              console.log("enter key needs to activate line selection")
              this.startSelect();
          }
          else if (this.isSelecting == true) {
            console.log("gonna submitChunk");
            this.submitChunk();
          }
        }  
      }
    }
      

    this.chunkSelection = (e) => {
      
      // Arrow through lines
      if (['ArrowUp', 'ArrowDown'].includes(e.key)) {
        console.log("this.currentLine is " + this.currentLine + " and this.selectionStart is " + this.selectionStart);
        console.log("this.lineNumbers[i]: " + this.lineNumbers[this.currentLine].innerText);
        // Find next/previous line number element
        const nextLineNum = e.key === 'ArrowUp' ? Math.max(this.currentLine - 1, this.selectionStart) : Math.min(this.currentLine + 1, this.lineCount);
        console.log("nextLineNum: " + nextLineNum);
        const nextEl = this.lineNumbers[nextLineNum];
        console.log("nextEl: " + nextEl.innerText)
        nextEl.focus();
        this.currentLine = nextLineNum;
        // Also update gridcell
        const gridCell = nextEl.parentElement;
        console.log("gridCell: " + gridCell)
        this.currentRow = gridCell.dataset.rowIndex;
        this.currentCol = gridCell.dataset.colIndex;
        console.log("Updated this.currentRow and this.currentCol to " + this.currentRow + ", " + this.currentCol)
        // Change selection if shift key was down
        // const lineNumber = parseInt(nextEl.dataset.lineNumber);
        if (e.shiftKey && this.selectionStart !== null) {
          console.log("shift-arrow is updating selection. this.selectionStart is type " + typeof(this.selectionStart) + " and nextLineNum is type " + typeof(nextLineNum))
          this.pushEvent("update_selection", {
            start: this.selectionStart,
            end: nextLineNum
          });
        }
      }
      if (e.key === ' ' && this.isSelecting) {
        console.log("space key in chunkSelection")
        if (!this.selectionStart) {
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

    this.clearSelection = () => {
      console.log("clearing selection")
      this.selectionStart = null;
      this.currentLine = null;
      this.isSelecting = false;
      (document.querySelectorAll(".selectedline")).forEach((selectedline) => selectedline.classList.remove("selectedline"));
      this.pushEvent("cancel_selection", {});
      this.el.addEventListener('mousedown', this.handlemousedown);
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
      console.log("this.startSelect invoked with enter key at row " + this.currentRow + ", col " + this.currentCol);
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
      console.log("submitChunk: pushing rechunk event")
      this.pushEvent("rechunk");
      this.clearSelection();
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
      console.log("this.focusCell: this.currentRow, this.currentCol: " + this.currentRow + ", " + this.currentCol)
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
    this.el.addEventListener('mousedown', this.handlemousedown);
  },

  destroyed() {
    this.el.removeEventListener('keyup', this.handlekeyup);
    this.el.removeEventListener('mousedown', this.handlemousedown);
    this.el.removeEventListener('mouseleave', this.handlemouseleave);

  }
};