# Edit Command Workflow

```mermaid
flowchart TD
    A[User Action] --> B{Action Type}
    
    B -->|Press e on commit| C[Single Commit Edit]
    B -->|leader+a action menu| D[Action Menu]
    
    %% Single Commit Edit Flow
    C --> E[Get commit under cursor]
    E --> F{Valid Commit?}
    F -->|No| G[Show error - no commit selected]
    F -->|Yes| H[Extract change_id]
    
    %% Action Menu Flow
    D --> I{Menu Selection}
    I -->|Single Selection| J[Edit commit e]
    J --> E
    
    %% Core Edit Process
    H --> K[edit_commit function]
    K --> L[Validate commit exists]
    L --> M{Commit Valid?}
    M -->|No| N[Show error - invalid commit]
    M -->|Yes| O[Build jj edit command]
    
    O --> P[jj edit change_id]
    P --> Q[commands.execute_with_immutable_prompt]
    Q --> R[Execute command]
    R --> S{Success?}
    
    S -->|Yes| T[Show success notification]
    S -->|No| U[Show error message]
    
    %% Success Path
    T --> V[get_edit_description]
    V --> W[Show descriptive message]
    W --> X[Refresh log display]
    X --> Y[Update working directory indicator]
    
    %% Error Handling
    G --> Z[Return to previous state]
    N --> Z
    U --> Z
    
    %% Styling
    classDef userAction fill:#e1f5fe
    classDef validation fill:#fff3e0
    classDef execution fill:#e8f5e8
    classDef success fill:#e8f5e8
    classDef error fill:#ffebee
    
    class A,B,C,D userAction
    class E,F,H,L,M,V validation
    class K,O,P,Q,R execution
    class T,W,X,Y success
    class G,N,U,Z error
```

## Key Features

- **Simple Operation**: Direct execution without complex menus
- **Working Directory Update**: Moves working directory to selected commit
- **Validation**: Ensures valid commit is selected
- **Descriptive Feedback**: Shows user-friendly description of edit operation

## Command Details

- **JJ Command**: `jj edit <change_id>`
- **Effect**: Changes the working directory to point to the specified commit
- **Use Case**: Switch to a different commit to make changes

## File Locations

- **Core**: `lua/jj-nvim/jj/edit.lua`
- **Actions**: `lua/jj-nvim/jj/actions.lua:507-508`
- **Action Menu**: `lua/jj-nvim/ui/action_menu.lua:108-113`
- **Keybinding**: `e` key for edit operation